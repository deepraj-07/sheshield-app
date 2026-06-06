import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../core/utils/logger.dart';
import '../models/contact_model.dart';
import '../models/stealth_session_model.dart';
import '../services/email_service.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';
import 'iot_trigger_service.dart';

/// Internal resolved contact — holds name, phone, and optional email.
class _ResolvedContact {
  final String name;
  final String phone;
  final String email;

  const _ResolvedContact({
    required this.name,
    required this.phone,
    required this.email,
  });
}

/// StealthModeService — orchestrates the complete stealth emergency flow.
///
/// Flow when triggered:
///   1. Create Firestore emergency session
///   2. Fetch GPS location
///   3. Start continuous live location tracking → writes to Firestore sub-collection
///   4. Send silent SMS to emergency contacts
///   5. Send email alert via native mail app (mailto: URI)
///   6. Write RTDB alert (IoT devices react)
///   7. Activate IoT hooks (RPi, BLE placeholders)
///   8. On stop: mark session ended, stop tracking
class StealthModeService {
  static final StealthModeService _instance = StealthModeService._internal();
  factory StealthModeService() => _instance;
  StealthModeService._internal();

  static const _rtdbUrl =
      'https://sheshield-bd387-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseService _firebase = FirebaseService();
  final LocationService _location = LocationService();
  final SmsService _sms = SmsService();
  final EmailService _email = EmailService();
  final IotTriggerService _iot = IotTriggerService();

  // ── Session state ──────────────────────────────────────────────────────────
  bool _isActive = false;
  String? _sessionId;
  StreamSubscription<Position>? _locationSub;
  int _locationUpdateCount = 0;

  bool get isActive => _isActive;
  String? get activeSessionId => _sessionId;

  // ── Trigger ────────────────────────────────────────────────────────────────

  /// Main entry point — call when stealth trigger fires.
  /// [triggerSource]: 'tap_pattern' | 'in_app' | 'power_button'
  /// [contacts]: pass from AppState; if empty, loads from LocalStorageService
  Future<void> activate({
    String triggerSource = 'tap_pattern',
    List<ContactModel> contacts = const [],
  }) async {
    if (_isActive) {
      AppLogger.w(
          'StealthModeService: already active, ignoring duplicate trigger');
      return;
    }
    _isActive = true;
    _sessionId = 'stealth_${DateTime.now().millisecondsSinceEpoch}';
    _locationUpdateCount = 0;

    AppLogger.i('StealthModeService: activating session $_sessionId');

    try {
      await _firebase.init();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final userName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'SheShield User';

      // ── Resolve contacts ────────────────────────────────────────────────────
      // Priority: passed ContactModel list → LocalStorageService (UI contacts)
      List<_ResolvedContact> resolvedContacts = [];

      if (contacts.isNotEmpty) {
        resolvedContacts = contacts
            .map((c) => _ResolvedContact(
                  name: c.name,
                  phone: c.cleanPhoneNumber,
                  email: '', // ContactModel has no email field
                ))
            .toList();
      } else {
        // Load from SharedPreferences — this is where UI contacts are saved
        final stored = await LocalStorageService.loadContacts();
        resolvedContacts = stored
            .where((c) => c.phone.isNotEmpty)
            .map((c) => _ResolvedContact(
                  name: c.name,
                  phone: c.phone,
                  email: c.email,
                ))
            .toList();
        AppLogger.i(
            'StealthModeService: loaded ${resolvedContacts.length} contacts from local storage');
      }

      if (resolvedContacts.isEmpty) {
        AppLogger.w(
            'StealthModeService: NO CONTACTS FOUND — SMS/email will not be sent');
      }

      // ── Create Firestore session ────────────────────────────────────────────
      final session = StealthSessionModel(
        sessionId: _sessionId!,
        userId: uid,
        startedAt: DateTime.now(),
        status: 'active',
        stealthModeEnabled: true,
        triggerSource: triggerSource,
        contactsNotified: resolvedContacts.map((c) => c.phone).toList(),
      );
      await _saveSession(session);

      // ── Fetch GPS location ──────────────────────────────────────────────────
      double? lat, lng;
      try {
        final pos = await _location
            .getCurrentLocationWithFallback()
            .timeout(const Duration(seconds: 20));
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
          AppLogger.i('StealthModeService: initial location $lat,$lng');
          await _firebase.firestore
              .collection('emergency_sessions')
              .doc(_sessionId)
              .update({'initialLatitude': lat, 'initialLongitude': lng});
        }
      } catch (e) {
        AppLogger.w('StealthModeService: initial location failed: $e');
      }

      // ── Start continuous location tracking ─────────────────────────────────
      _startLocationTracking();

      // ── Send SMS to all contacts ───────────────────────────────────────────
      if (resolvedContacts.isNotEmpty) {
        unawaited(_sendSmsToContacts(resolvedContacts, lat, lng, userName));
      }

      // ── Send email via native mail app ─────────────────────────────────────
      if (resolvedContacts.isNotEmpty) {
        unawaited(_sendEmailAlert(resolvedContacts, lat, lng, userName));
      }

      // ── Write RTDB alert ────────────────────────────────────────────────────
      unawaited(
          _writeRtdbStealthAlert(lat: lat, lng: lng, sessionId: _sessionId!));

      // ── Activate IoT hooks ──────────────────────────────────────────────────
      unawaited(_iot.activateStealthMode(sessionId: _sessionId!));

      AppLogger.i(
          'StealthModeService: session $_sessionId fully activated. Contacts: ${resolvedContacts.length}');
    } catch (e, st) {
      AppLogger.e('StealthModeService: activation failed', e, st);
      _isActive = false;
    }
  }

  /// Stop the active stealth session.
  Future<void> deactivate() async {
    if (!_isActive) return;
    AppLogger.i('StealthModeService: deactivating session $_sessionId');

    _locationSub?.cancel();
    _locationSub = null;

    // Mark session ended in Firestore
    if (_sessionId != null) {
      try {
        await _firebase.firestore
            .collection('emergency_sessions')
            .doc(_sessionId)
            .update({
          'status': 'ended',
          'endedAt': DateTime.now().millisecondsSinceEpoch,
          'totalLocationUpdates': _locationUpdateCount,
        });
      } catch (e) {
        AppLogger.w('StealthModeService: failed to mark session ended: $e');
      }
    }

    // Clear RTDB stealth alert
    unawaited(_clearRtdbStealthAlert());

    // Deactivate IoT hooks
    unawaited(_iot.deactivateStealthMode());

    _isActive = false;
    _sessionId = null;
    AppLogger.i('StealthModeService: session deactivated');
  }

  // ── Location tracking ──────────────────────────────────────────────────────

  void _startLocationTracking() {
    _locationSub?.cancel();
    try {
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // update every 10m movement
        ),
      ).listen(
        (pos) => _onLocationUpdate(pos),
        onError: (e) =>
            AppLogger.w('StealthModeService: location stream error: $e'),
      );
      AppLogger.i('StealthModeService: location tracking started');
    } catch (e) {
      AppLogger.w('StealthModeService: failed to start location stream: $e');
    }
  }

  void _onLocationUpdate(Position pos) {
    if (!_isActive || _sessionId == null) return;
    _locationUpdateCount++;

    final update = StealthLocationUpdate(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      accuracy: pos.accuracy,
    );

    // Write to Firestore sub-collection (fire-and-forget)
    _firebase.firestore
        .collection('emergency_sessions')
        .doc(_sessionId)
        .collection('locations')
        .add(update.toFirestore())
        .ignore();

    // Also update RTDB for real-time dashboard
    _updateRtdbLocation(pos.latitude, pos.longitude);

    AppLogger.d(
        'StealthModeService: location update #$_locationUpdateCount: ${pos.latitude},${pos.longitude}');
  }

  // ── SMS ────────────────────────────────────────────────────────────────────

  /// Send SMS to resolved contacts using SmsService.
  Future<void> _sendSmsToContacts(
    List<_ResolvedContact> contacts,
    double? lat,
    double? lng,
    String userName,
  ) async {
    try {
      // Build ContactModel list from resolved contacts for SmsService
      final contactModels = contacts
          .map((c) => ContactModel(
                contactId: c.phone,
                userId: 'stealth',
                name: c.name,
                phoneNumber: c.phone,
                createdAt: DateTime.now(),
              ))
          .toList();

      final double safeLat = lat ?? 0.0;
      final double safeLng = lng ?? 0.0;

      await _sms.sendEmergencySMS(
        contactModels,
        safeLat,
        safeLng,
        displayName: userName,
        address: null,
      );

      AppLogger.i(
          'StealthModeService: SMS sent to ${contacts.length} contacts');

      // Log SMS evidence to Firestore
      if (_sessionId != null) {
        await _firebase.firestore
            .collection('emergency_sessions')
            .doc(_sessionId)
            .collection('evidence')
            .add({
          'type': 'sms_alert',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'contactCount': contacts.length,
          'mapsUrl': lat != null
              ? 'https://maps.google.com/?q=$lat,$lng'
              : 'location unavailable',
        });
      }
    } catch (e) {
      AppLogger.w('StealthModeService: SMS failed: $e');
    }
  }

  // ── Email ──────────────────────────────────────────────────────────────────

  /// Send email alert via SMTP silently in the background.
  /// Contacts without an email address are skipped.
  Future<void> _sendEmailAlert(
    List<_ResolvedContact> contacts,
    double? lat,
    double? lng,
    String userName,
  ) async {
    try {
      final emailContacts = contacts
          .where((c) => c.email.trim().isNotEmpty)
          .map((c) => EmailContact(name: c.name, email: c.email.trim()))
          .toList();

      if (emailContacts.isEmpty) {
        AppLogger.w(
            'StealthModeService: no email addresses — skipping email alert');
        return;
      }

      final sent = await _email.sendEmergencyEmail(
        contacts: emailContacts,
        senderName: userName,
        latitude: lat,
        longitude: lng,
        triggerSource: 'Stealth SOS',
      );

      AppLogger.i(
          'StealthModeService: $sent email(s) sent to ${emailContacts.length} contacts');

      // Log email evidence to Firestore
      if (_sessionId != null && sent > 0) {
        await _firebase.firestore
            .collection('emergency_sessions')
            .doc(_sessionId)
            .collection('evidence')
            .add({
          'type': 'email_alert',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'contactCount': sent,
          'recipients': emailContacts.map((c) => c.email).toList(),
          'mapsUrl': lat != null
              ? 'https://maps.google.com/?q=$lat,$lng'
              : 'location unavailable',
        });
      }
    } catch (e) {
      AppLogger.w('StealthModeService: email alert failed: $e');
    }
  }

  // ── RTDB ───────────────────────────────────────────────────────────────────

  Future<void> _writeRtdbStealthAlert({
    double? lat,
    double? lng,
    required String sessionId,
  }) async {
    try {
      final db = FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: _rtdbUrl);
      await db.ref('current_status').update({
        'status': 'Stealth SOS Active',
        'is_alert': true,
        'trigger_source': 'stealth',
        'latitude': lat,
        'longitude': lng,
        'triggered_by': 'app',
        'stealth_session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      AppLogger.w('StealthModeService: RTDB write failed: $e');
    }
  }

  Future<void> _updateRtdbLocation(double lat, double lng) async {
    try {
      final db = FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: _rtdbUrl);
      await db.ref('current_status').update({
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> _clearRtdbStealthAlert() async {
    try {
      final db = FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: _rtdbUrl);
      await db.ref('current_status').update({
        'status': 'Safe',
        'is_alert': false,
        'stealth_session_id': null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      AppLogger.w('StealthModeService: RTDB clear failed: $e');
    }
  }

  // ── Firestore session ──────────────────────────────────────────────────────

  Future<void> _saveSession(StealthSessionModel session) async {
    await _firebase.firestore
        .collection('emergency_sessions')
        .doc(session.sessionId)
        .set(session.toFirestore());
    AppLogger.i('StealthModeService: session saved to Firestore');
  }

  /// Upload a file (audio/image) as evidence for the active session.
  /// Returns the download URL or null on failure.
  Future<String?> uploadEvidence(
    List<int> bytes, {
    required String fileName,
    required String contentType,
  }) async {
    if (_sessionId == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('stealth_evidence/$_sessionId/$fileName');
      final task = await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: contentType),
      );
      final url = await task.ref.getDownloadURL();

      // Log to Firestore evidence sub-collection
      await _firebase.firestore
          .collection('emergency_sessions')
          .doc(_sessionId)
          .collection('evidence')
          .add({
        'type': contentType.startsWith('audio') ? 'audio' : 'image',
        'url': url,
        'fileName': fileName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      AppLogger.i('StealthModeService: evidence uploaded: $url');
      return url;
    } catch (e) {
      AppLogger.w('StealthModeService: evidence upload failed: $e');
      return null;
    }
  }
}
