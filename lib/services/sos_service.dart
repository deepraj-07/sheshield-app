import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../models/contact_model.dart';
import '../models/sos_event_model.dart';
import '../providers/app_state.dart';
import 'bluetooth_service.dart';
import 'email_service.dart';
import 'evidence_service.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
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
  final EmailService _emailService = EmailService();
  final VideoService _videoService = VideoService();
  final EvidenceService _evidenceService = EvidenceService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseService _firebaseService = FirebaseService();

  // AppState reference â€” set once from main.dart or home_screen after providers init
  AppState? _appState;
  void setAppState(AppState state) {
    _appState = state;
    _startHardwareTriggerListener();
  }

  StreamSubscription<DatabaseEvent>? _hardwareListenerSub;

  void _startHardwareTriggerListener() {
    _hardwareListenerSub?.cancel();
    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _rtdbUrl,
      );
      _hardwareListenerSub = db.ref('current_status/is_alert').onValue.listen(
        (event) {
          final bool isAlert = event.snapshot.value as bool? ?? false;
          AppLogger.i(
              'RTDB hw-listener: is_alert=$isAlert appSOS=$_isSOSActive');
          if (isAlert && !_isSOSActive) {
            AppLogger.step(
                'RTDB', 'HW', 'Hardware trigger detected — starting SOS');
            _appState?.setSosState(SosState.active);
            unawaited(triggerSOS(triggerSource: 'hardware'));
          }
        },
        onError: (e) => AppLogger.taggedError(
            'RTDB', 'HW listener error', e, StackTrace.current),
      );
      AppLogger.i('SOSService: hardware trigger listener started');
    } catch (e, st) {
      AppLogger.taggedError('RTDB', 'Failed to start HW listener', e, st);
    }
  }

  void stopHardwareTriggerListener() {
    _hardwareListenerSub?.cancel();
    _hardwareListenerSub = null;
  }

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
      AppLogger.taggedError('SOS', 'Duplicate SOS trigger ignored',
          'already-active', StackTrace.current);
      return false;
    }

    _isSOSActive = true;
    _sosTriggeredAt = DateTime.now();
    _activeSOSEventId = 'sos_${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.step('SOS', '0', 'SOS triggered from $triggerSource');
    AppLogger.i('SOS flow started: $_activeSOSEventId');

    // Write RTDB alert IMMEDIATELY
    unawaited(_writeRtdbAlertImmediate(
        triggerSource: triggerSource, bpm: currentBPM));

    // Save a minimal SOS event to Firestore RIGHT NOW so it appears
    // in EvidenceOverview instantly, before GPS/video completes.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      final immediateEvent = SosEventModel(
        eventId: _activeSOSEventId!,
        userId: uid,
        timestamp: _sosTriggeredAt!,
        latitude: 0.0,
        longitude: 0.0,
        triggerSource: triggerSource,
        bpmAtTrigger: currentBPM,
        contactsNotified: const [],
      );
      unawaited(_saveSosEvent(immediateEvent));
    }

    try {
      final location = await _retry<LocationDataProxy>(
        () async => _fetchCurrentLocation(),
        attempts: 2,
        delayMs: 500,
      );
      final latitude = location.latitude;
      final longitude = location.longitude;
      AppLogger.step('GPS', '1', 'Location acquired: $latitude,$longitude');

      await _writeRtdbAlert(
        latitude: latitude,
        longitude: longitude,
        triggerSource: triggerSource,
        bpm: currentBPM,
      );

      String? address;
      try {
        address = await _locationService
            .getAddressFromCoordinates(latitude, longitude)
            .timeout(const Duration(seconds: 10));
      } catch (e, st) {
        AppLogger.taggedError('GPS', 'Reverse geocode failed', e, st);
      }

      final contacts = await _retry<List<ContactModel>>(
        () async => _fetchEmergencyContacts(),
        attempts: 2,
        delayMs: 500,
      );

      try {
        await _smsService
            .sendEmergencySMS(
              contacts,
              latitude,
              longitude,
              address: address,
              displayName: _displayName,
            )
            .timeout(const Duration(seconds: 20));
      } catch (e, st) {
        AppLogger.taggedError('SMS', 'Emergency SMS dispatch failed', e, st);
      }

      unawaited(_sendEmailAlerts(
        contacts: contacts,
        latitude: latitude,
        longitude: longitude,
        address: address,
        triggerSource: triggerSource,
      ));

      final videoFuture = _videoService.recordEmergencyVideo();
      final videoPath = await videoFuture.timeout(
        Duration(seconds: AppConstants.sosVideoRecordDurationSec + 20),
        onTimeout: () => null,
      );

      Map<String, dynamic>? evidenceResult;
      if (videoPath != null) {
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
        } catch (e, st) {
          AppLogger.taggedError('FIREBASE', 'Evidence upload failed', e, st);
        }
      }

      // Update the Firestore doc with full GPS, address, contacts, video
      if (uid != null && uid.isNotEmpty) {
        final fullEvent = SosEventModel(
          eventId: _activeSOSEventId!,
          userId: uid,
          timestamp: _sosTriggeredAt!,
          latitude: latitude,
          longitude: longitude,
          address: address,
          videoUrl: evidenceResult?['videoUrl'] as String?,
          sha256Hash: evidenceResult?['hash'] as String?,
          bpmAtTrigger: currentBPM,
          triggerSource: triggerSource,
          contactsNotified:
              contacts.map((c) => c.cleanPhoneNumber).toList(growable: false),
        );
        unawaited(_saveSosEvent(fullEvent));
      }

      if (evidenceResult?['videoUrl'] != null) {
        unawaited(_writeRtdbAlert(
          latitude: latitude,
          longitude: longitude,
          triggerSource: triggerSource,
          bpm: currentBPM,
          videoUrl: evidenceResult!['videoUrl'] as String,
        ));
      }

      final tokens = await _fetchContactTokens(contacts);
      if (tokens.isNotEmpty) {
        final notificationMessage = _buildNotificationMessage(
          displayName: _displayName,
          latitude: latitude,
          longitude: longitude,
          timestamp: _sosTriggeredAt!,
        );
        try {
          await _notificationService.sendSOSNotification(
              tokens, notificationMessage);
        } catch (e, st) {
          AppLogger.taggedError('FIREBASE', 'Push notification failed', e, st);
        }
      }

      try {
        await _bluetoothService.vibrateBracelet();
        await _bluetoothService.ledOn();
        await _bluetoothService.buzzerOn();
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
      _appState?.notifySosEventSaved();
    } catch (e, st) {
      AppLogger.taggedError('FIREBASE', 'SOS event save failed', e, st);
    }
  }

  static const _rtdbUrl =
      'https://sheshield-bd387-default-rtdb.asia-southeast1.firebasedatabase.app';

  Future<void> _writeRtdbAlertImmediate(
      {required String triggerSource, int? bpm}) async {
    try {
      final db = FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: _rtdbUrl);
      await db.ref('current_status').update({
        'status': 'SOS Active - Emergency Alert',
        'is_alert': true,
        'trigger_source': triggerSource,
        'bpm': bpm,
        'triggered_by': 'app',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      AppLogger.taggedError('RTDB', 'Immediate alert write failed', e, st);
    }
  }

  Future<void> _writeRtdbAlert({
    required double latitude,
    required double longitude,
    required String triggerSource,
    int? bpm,
    String? videoUrl,
  }) async {
    try {
      final db = FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: _rtdbUrl);
      await db.ref('current_status').set({
        'status': 'SOS Active - Emergency Alert',
        'is_alert': true,
        'trigger_source': triggerSource,
        'latitude': latitude,
        'longitude': longitude,
        'bpm': bpm,
        'video_url': videoUrl ?? '',
        'triggered_by': 'app',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      AppLogger.taggedError('RTDB', 'RTDB alert write failed', e, st);
    }
  }

  Future<void> writeRtdbSafe() async {
    try {
      final db = FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: _rtdbUrl);
      await db.ref('current_status').set({
        'status': 'Safe',
        'is_alert': false,
        'bpm': null,
        'video_url': '',
        'triggered_by': 'app',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      AppLogger.taggedError('RTDB', 'RTDB safe write failed', e, st);
    }
  }

  Future<List<ContactModel>> _fetchEmergencyContacts() async {
    try {
      final stored = await LocalStorageService.loadContacts();
      if (stored.isNotEmpty) {
        return stored
            .where((c) => c.phone.isNotEmpty)
            .map((c) => ContactModel(
                  contactId: '${c.name}_${c.phone}'.hashCode.toString(),
                  userId: FirebaseAuth.instance.currentUser?.uid ?? 'local',
                  name: c.name,
                  phoneNumber: c.phone,
                  relationship: c.relation,
                  createdAt: DateTime.now(),
                ))
            .toList(growable: false);
      }
    } catch (e) {
      AppLogger.w('SOSService: local storage contact load failed: $e');
    }

    final appStateContacts = _appState?.emergencyContacts ?? [];
    if (appStateContacts.isNotEmpty) return appStateContacts;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return <ContactModel>[];

    try {
      final snapshot = await _firebaseService.firestore
          .collection(AppConstants.firestoreContactsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('priority')
          .get();
      return snapshot.docs
          .map(ContactModel.fromFirestore)
          .toList(growable: false);
    } catch (e) {
      AppLogger.w('SOSService: Firestore contact load failed: $e');
      return <ContactModel>[];
    }
  }

  Future<void> _sendEmailAlerts({
    required List<ContactModel> contacts,
    required double latitude,
    required double longitude,
    String? address,
    required String triggerSource,
  }) async {
    try {
      final stored = await LocalStorageService.loadContacts();
      final emailContacts = stored
          .where((c) => c.email.trim().isNotEmpty)
          .map((c) => EmailContact(name: c.name, email: c.email.trim()))
          .toList();
      if (emailContacts.isEmpty) return;
      await _emailService.sendEmergencyEmail(
        contacts: emailContacts,
        senderName: _displayName,
        latitude: latitude,
        longitude: longitude,
        address: address,
        triggerSource: triggerSource,
      );
    } catch (e, st) {
      AppLogger.taggedError('EMAIL', 'Email alert dispatch failed', e, st);
    }
  }

  Future<List<String>> _fetchContactTokens(List<ContactModel> contacts) async {
    final tokens = <String>{};
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return <String>[];
    for (final contact in contacts) {
      try {
        final doc = await _firebaseService.firestore
            .collection(AppConstants.firestoreContactsCollection)
            .doc(contact.contactId)
            .get();
        final data = doc.data();
        if (data == null) continue;
        final dynamic deviceTokens = data['deviceTokens'];
        if (deviceTokens is List) {
          for (final token in deviceTokens) {
            if (token is String && token.isNotEmpty) tokens.add(token);
          }
        }
        final singleToken = data['deviceToken'];
        if (singleToken is String && singleToken.isNotEmpty) {
          tokens.add(singleToken);
        }
      } catch (_) {}
    }
    return tokens.toList(growable: false);
  }

  Future<LocationDataProxy> _fetchCurrentLocation() async {
    final position =
        await _locationService.getCurrentLocationWithFallback().timeout(
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
    if (user?.email != null && user!.email!.isNotEmpty) return user.email!;
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

  Future<T> _retry<T>(Future<T> Function() action,
      {int attempts = 3, int delayMs = 500}) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var i = 1; i <= attempts; i++) {
      try {
        return await action();
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        if (i < attempts) {
          await Future.delayed(Duration(milliseconds: delayMs * i));
        }
      }
    }
    Error.throwWithStackTrace(lastError ?? StateError('Unknown retry failure'),
        lastStack ?? StackTrace.current);
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
