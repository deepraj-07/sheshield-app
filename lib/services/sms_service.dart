import 'dart:async';
import 'package:telephony/telephony.dart';

import '../core/utils/logger.dart';
import '../models/contact_model.dart';

/// SmsService uses the `telephony` plugin to send SMS messages directly.
/// It includes permission handling, retry logic, and per-contact logging.
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony _telephony = Telephony.instance;

  /// Send emergency SMS to a list of contacts with a Google Maps link.
  /// This method will not block the UI; it returns after scheduling sends.
  Future<void> sendEmergencySMS(List<ContactModel> contacts, double lat, double lng, {String? address, String? displayName}) async {
    AppLogger.i('SmsService: Preparing to send SMS to ${contacts.length} contacts');

    try {
      // Request SMS permission if needed
      final permissionsGranted = await _telephony.requestSmsPermissions ?? false;
      if (!permissionsGranted) {
        AppLogger.w('SmsService: SMS permission not granted');
      }

      final mapUrl = 'https://maps.google.com/?q=$lat,$lng';
      final timeStr = DateTime.now().toIso8601String();

      final fromName = displayName ?? 'A friend';

      // Compose message once
      final messageBuffer = StringBuffer();
      messageBuffer.writeln('EMERGENCY!');
      messageBuffer.writeln('$fromName has triggered an SOS.');
      messageBuffer.writeln('Time: $timeStr');
      messageBuffer.writeln('Location: $mapUrl');
      if (address != null && address.isNotEmpty) {
        messageBuffer.writeln('Address: $address');
      }
      messageBuffer.writeln('Please respond immediately.');
      final message = messageBuffer.toString();

      // Send to each contact with retry logic
      for (final contact in contacts) {
        final to = contact.cleanPhoneNumber;
        if (to.isEmpty) {
          AppLogger.w('SmsService: Skipping contact with empty phone: ${contact.name}');
          continue;
        }

        // Attempt send with retries
        const int maxAttempts = 3;
        int attempt = 0;
        bool sent = false;

        while (attempt < maxAttempts && !sent) {
          attempt += 1;
          try {
            AppLogger.i('SmsService: Sending SMS to $to (attempt $attempt)');
            await _telephony.sendSms(
              to: to,
              message: message,
              statusListener: (SendStatus status) {
                AppLogger.d('SmsService: status for $to -> $status');
              },
            );

            // Telephony's sendSms does not throw on Android; assume sent
            AppLogger.i('SmsService: SMS queued for $to');
            sent = true;
          } catch (e, st) {
            AppLogger.e('SmsService: Failed to send SMS to $to on attempt $attempt', e, st);
            // exponential backoff
            final delayMs = 500 * attempt;
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }

        if (!sent) {
          AppLogger.w('SmsService: Giving up sending SMS to $to after $maxAttempts attempts');
        }
      }
    } catch (e, st) {
      AppLogger.e('SmsService: sendEmergencySMS failed', e, st);
    }
  }
}
