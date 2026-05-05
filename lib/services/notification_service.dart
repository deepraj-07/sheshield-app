import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_env.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import 'firebase_service.dart';

/// NotificationService handles FCM token storage and SOS notification dispatch.
///
/// Direct push delivery from a client app is not always possible without a
/// trusted server credential. This service therefore:
/// 1. Stores device tokens in Firestore.
/// 2. Attempts direct FCM delivery when an FCM server key is configured.
/// 3. Falls back to enqueuing a Firestore notification request for a backend
///    worker / Cloud Function when direct delivery is unavailable.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// FCM server key read from .env at runtime via AppEnv.
  String get _serverKey => AppEnv.fcmServerKey;

  /// Initialize notification permissions and capture the current device token.
  Future<String?> initializeForCurrentUser({required String userId}) async {
    try {
      await _firebaseService.init();

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await storeDeviceToken(userId: userId, token: token);
        AppLogger.step('FIREBASE', 'TOKEN', 'Current device token stored');
      }

      return token;
    } catch (e, st) {
      AppLogger.taggedError(
          'FIREBASE', 'Notification initialization failed', e, st);
      return null;
    }
  }

  /// Store a device token in Firestore for later FCM delivery.
  Future<void> storeDeviceToken(
      {required String userId,
      required String token,
      String? contactId}) async {
    try {
      await _firebaseService.init();
      final tokenDoc = <String, dynamic>{
        'token': token,
        'userId': userId,
        'contactId': contactId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firebaseService.firestore
          .collection('device_tokens')
          .doc(token)
          .set(tokenDoc, SetOptions(merge: true));

      if (contactId != null && contactId.isNotEmpty) {
        await _firebaseService.firestore
            .collection(AppConstants.firestoreContactsCollection)
            .doc(contactId)
            .set({
          'deviceToken': token,
          'deviceTokens': FieldValue.arrayUnion([token]),
          'deviceTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      AppLogger.step('FIREBASE', 'TOKEN', 'Device token stored for $userId');
    } catch (e, st) {
      AppLogger.taggedError('FIREBASE', 'Failed to store device token', e, st);
    }
  }

  /// Send an SOS notification to a set of device tokens.
  /// Retries the send request and falls back to a Firestore queue if needed.
  Future<void> sendSOSNotification(List<String> tokens, String message) async {
    if (tokens.isEmpty) {
      AppLogger.w('FIREBASE No device tokens supplied for SOS notification');
      return;
    }

    AppLogger.step('FIREBASE', '8',
        'Sending SOS push notifications to ${tokens.length} tokens');

    final uniqueTokens = tokens
        .where((token) => token.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueTokens.isEmpty) {
      AppLogger.w('FIREBASE No valid device tokens after filtering');
      return;
    }

    final title = 'SheShield SOS Alert';
    final body = message.trim();

    if (_serverKey.isNotEmpty) {
      await _sendViaLegacyFcm(uniqueTokens, title: title, body: body);
      return;
    }

    await _enqueueNotificationRequest(uniqueTokens, title: title, body: body);
  }

  Future<void> _sendViaLegacyFcm(List<String> tokens,
      {required String title, required String body}) async {
    final uri = Uri.parse('https://fcm.googleapis.com/fcm/send');
    final payload = <String, dynamic>{
      'registration_ids': tokens,
      'priority': 'high',
      'notification': <String, dynamic>{
        'title': title,
        'body': body,
        'sound': 'default',
      },
      'data': <String, dynamic>{
        'type': 'sos',
        'timestamp': DateTime.now().toIso8601String(),
      },
    };

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .post(
              uri,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'key=$_serverKey',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: AppConstants.fcmTimeoutSec));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          AppLogger.step(
              'FIREBASE', '8', 'FCM response: ${response.statusCode}');
          return;
        }

        throw HttpException(
            'FCM returned ${response.statusCode}: ${response.body}');
      } catch (e, st) {
        AppLogger.taggedError(
            'FIREBASE', 'FCM send attempt $attempt failed', e, st);
        if (attempt == 3) {
          await _enqueueNotificationRequest(tokens, title: title, body: body);
          return;
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  Future<void> _enqueueNotificationRequest(List<String> tokens,
      {required String title, required String body}) async {
    try {
      await _firebaseService.init();
      await _firebaseService.firestore
          .collection('notification_requests')
          .add(<String, dynamic>{
        'tokens': tokens,
        'title': title,
        'body': body,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      AppLogger.w(
          'FIREBASE FCM server key unavailable; notification request queued');
    } catch (e, st) {
      AppLogger.taggedError(
          'FIREBASE', 'Failed to enqueue notification request', e, st);
    }
  }
}
