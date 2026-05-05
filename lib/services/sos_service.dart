import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../models/contact_model.dart';
import '../models/sos_event_model.dart';
import 'bluetooth_service.dart';
import 'evidence_service.dart';
import 'firebase_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'sms_service.dart';
import 'video_service.dart';

/// SOSService orchestrates the complete SOS response flow.
/// It is a singleton and guarantees one active execution at a time.
class SOSService {
  static final SOSService _instance = SOSService._internal();

  factory SOSService() => _instance;

  SOSService._internal() {
    try {
      _bluetoothService.registerOnSosCallback(() {
        unawaited(triggerSOS(triggerSource: 'bracelet'));
      });
    } catch (e, st) {
      AppLogger.taggedError('BT', 'Failed to register SOS callback', e, st);
    }
  }

  final LocationService _locationService = LocationService();
  final BluetoothService _bluetoothService = BluetoothService();
  final SmsService _smsService = SmsService();
  final VideoService _videoService = VideoService();
  final EvidenceService _evidenceService = EvidenceService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isSOSActive = false;
  String? _activeSOSEventId;
  DateTime? _sosTriggeredAt;

  bool get isSOSActive => _isSOSActive;
  String? get activeSOSEventId => _activeSOSEventId;
  DateTime? get sosTriggeredAt => _sosTriggeredAt;

  Future<bool> triggerSOS({
    String triggerSource = 'button',
    int? currentBPM,
  }) async {
    if (_isSOSActive) {
      AppLogger.taggedError('SOS', 'Duplicate SOS trigger ignored', 'already-active', StackTrace.current);
      return false;
    }

    _isSOSActive = true;
    _sosTriggeredAt = DateTime.now();
    _activeSOSEventId = 'sos_${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.step('SOS', '0', 'SOS triggered from $triggerSource');
    AppLogger.i('SOS flow started: $_activeSOSEventId');

    try {
      final location = await _retry<LocationDataProxy>(
        () async => _fetchCurrentLocation(),
        attempts: 2,
        delayMs: 500,
      );
      final latitude = location.latitude;
      final longitude = location.longitude;
      AppLogger.step('GPS', '1', 'Location acquired: $latitude,$longitude');

      String? address;
      try {
        address = await _locationService.getAddressFromCoordinates(latitude, longitude).timeout(
          const Duration(seconds: 10),
        );
        AppLogger.step('GPS', '1.5', 'Reverse geocode resolved: ${address ?? 'unknown'}');
      } catch (e, st) {
        AppLogger.taggedError('GPS', 'Reverse geocode failed', e, st);
      }

      final contacts = await _retry<List<ContactModel>>(
        () async => _fetchEmergencyContacts(),
        attempts: 2,
        delayMs: 500,
      );

      AppLogger.step('SMS', '2', 'Sending SMS to ${contacts.length} emergency contacts');
      try {
        await _smsService.sendEmergencySMS(
          contacts,
          latitude,
          longitude,
          address: address,
          displayName: _displayName,
        ).timeout(const Duration(seconds: 20));
        AppLogger.step('SMS', '2', 'Emergency SMS dispatch completed');
      } catch (e, st) {
        AppLogger.taggedError('SMS', 'Emergency SMS dispatch failed', e, st);
      }

      AppLogger.step('VIDEO', '3', 'Starting emergency video recording');
      final videoFuture = _videoService.recordEmergencyVideo();
      AppLogger.step('VIDEO', '3', 'Video recording started asynchronously');

      AppLogger.step('VIDEO', '4', 'Waiting for recorded video file');
      final videoPath = await videoFuture.timeout(
        Duration(seconds: AppConstants.sosVideoRecordDurationSec + 20),
        onTimeout: () => null,
      );
      if (videoPath == null) {
        AppLogger.w('VIDEO recording timed out or returned null');
      } else {
        AppLogger.step('VIDEO', '4', 'Video file ready: $videoPath');
      }

      Map<String, dynamic>? evidenceResult;
      if (videoPath != null) {
        AppLogger.step('FIREBASE', '5-7', 'Hashing, uploading, and saving evidence');
        try {
          evidenceResult = await _retry<Map<String, dynamic>>(
            () => _evidenceService.uploadEvidence(
              File(videoPath),
              latitude: latitude,
              longitude: longitude,
              triggerType: triggerSource,
              sosEventId: _activeSOSEventId,
            ),
            attempts: 2,
            delayMs: 1000,
          );
          AppLogger.step('FIREBASE', '5-7', 'Evidence saved to Firestore and Storage');
        } catch (e, st) {
          AppLogger.taggedError('FIREBASE', 'Evidence upload/save failed', e, st);
        }
      }

      final sosEvent = SosEventModel(
        eventId: _activeSOSEventId!,
        userId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        timestamp: _sosTriggeredAt!,
        latitude: latitude,
        longitude: longitude,
        address: address,
        videoUrl: evidenceResult?['videoUrl'] as String?,
        sha256Hash: evidenceResult?['hash'] as String?,
        bpmAtTrigger: currentBPM,
        triggerSource: triggerSource,
        contactsNotified: contacts.map((c) => c.cleanPhoneNumber).toList(growable: false),
      );

      await _saveSosEvent(sosEvent);

      AppLogger.step('FIREBASE', '8', 'Fetching contact tokens for notification dispatch');
      final tokens = await _fetchContactTokens(contacts);
      if (tokens.isNotEmpty) {
        final notificationMessage = _buildNotificationMessage(
          displayName: _displayName,
          latitude: latitude,
          longitude: longitude,
          timestamp: _sosTriggeredAt!,
        );
        try {
          await _notificationService.sendSOSNotification(tokens, notificationMessage);
          AppLogger.step('FIREBASE', '8', 'Push notification dispatch completed');
        } catch (e, st) {
          AppLogger.taggedError('FIREBASE', 'Push notification dispatch failed', e, st);
        }
      } else {
        AppLogger.w('FIREBASE No device tokens found for emergency contacts');
      }

      AppLogger.step('BT', '9', 'Alerting bracelet');
      try {
        await _bluetoothService.vibrateBracelet();
        await _bluetoothService.ledOn();
        await _bluetoothService.buzzerOn();
        AppLogger.step('BT', '9', 'Bracelet alert commands sent');
      } catch (e, st) {
        AppLogger.taggedError('BT', 'Bracelet alert failed', e, st);
      }

      AppLogger.i('SOS flow completed successfully for $_activeSOSEventId');
      return true;
    } catch (e, st) {
      AppLogger.taggedError('SOS', 'Unhandled SOS failure', e, st);
      return false;
    } finally {
      Future.delayed(const Duration(seconds: 5), () {
        _isSOSActive = false;
        _activeSOSEventId = null;
      });
    }
  }

  Future<void> _saveSosEvent(SosEventModel event) async {
    try {
      await _firebaseService.init();
      await _firebaseService.firestore
          .collection(AppConstants.firestoreSosEventsCollection)
          .doc(event.eventId)
          .set(event.toFirestore());
      AppLogger.step('FIREBASE', '7', 'SOS event saved: ${event.eventId}');
    } catch (e, st) {
      AppLogger.taggedError('FIREBASE', 'SOS event save failed', e, st);
    }
  }

  Future<List<ContactModel>> _fetchEmergencyContacts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return <ContactModel>[];
    }

    final snapshot = await _firebaseService.firestore
        .collection(AppConstants.firestoreContactsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('priority')
        .get();

    return snapshot.docs.map(ContactModel.fromFirestore).toList(growable: false);
  }

  Future<List<String>> _fetchContactTokens(List<ContactModel> contacts) async {
    final tokens = <String>{};
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return <String>[];

    for (final contact in contacts) {
      final doc = await _firebaseService.firestore
          .collection(AppConstants.firestoreContactsCollection)
          .doc(contact.contactId)
          .get();
      final data = doc.data();
      if (data == null) continue;

      final dynamic deviceTokens = data['deviceTokens'];
      if (deviceTokens is List) {
        for (final token in deviceTokens) {
          if (token is String && token.isNotEmpty) {
            tokens.add(token);
          }
        }
      }

      final singleToken = data['deviceToken'];
      if (singleToken is String && singleToken.isNotEmpty) {
        tokens.add(singleToken);
      }
    }

    return tokens.toList(growable: false);
  }

  Future<LocationDataProxy> _fetchCurrentLocation() async {
    final position = await _locationService.getCurrentLocationWithFallback().timeout(
      const Duration(seconds: 30),
    );
    if (position == null) {
      throw TimeoutException('Unable to acquire current location');
    }
    return LocationDataProxy(position.latitude, position.longitude);
  }

  String get _displayName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email!;
    }
    return 'SheShield user';
  }

  String _buildNotificationMessage({
    required String displayName,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) {
    return '$displayName triggered SOS at ${timestamp.toIso8601String()}\nhttps://maps.google.com/?q=$latitude,$longitude';
  }

  Future<T> _retry<T>(Future<T> Function() action, {int attempts = 3, int delayMs = 500}) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var i = 1; i <= attempts; i++) {
      try {
        return await action();
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        AppLogger.w('Retry $i/$attempts failed: $e');
        if (i < attempts) {
          await Future.delayed(Duration(milliseconds: delayMs * i));
        }
      }
    }
    Error.throwWithStackTrace(lastError ?? StateError('Unknown retry failure'), lastStack ?? StackTrace.current);
  }

  void dispose() {
    _bluetoothService.unregisterOnSosCallback();
  }
}

class LocationDataProxy {
  final double latitude;
  final double longitude;

  const LocationDataProxy(this.latitude, this.longitude);
}
