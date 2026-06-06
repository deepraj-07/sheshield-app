import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../core/config/app_env.dart';
import '../core/utils/logger.dart';

/// Contact info passed to EmailService for sending alerts.
class EmailContact {
  final String name;
  final String email;

  const EmailContact({required this.name, required this.email});
}

/// EmailService sends real background SMTP emails without opening any UI.
///
/// Configuration (set in .env):
///   SMTP_HOST        — default: smtp.gmail.com
///   SMTP_PORT        — default: 587
///   SMTP_USERNAME    — your Gmail address
///   SMTP_PASSWORD    — Gmail App Password (16 chars, no spaces)
///   SMTP_FROM_NAME   — display name in From field
///
/// Gmail setup:
///   1. Enable 2-Step Verification on your Google account
///   2. Go to Google Account → Security → App passwords
///   3. Create an app password for "Mail" on "Android"
///   4. Paste the 16-char password into SMTP_PASSWORD in .env
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  /// Send emergency email alert to all contacts that have an email address.
  /// Fires silently in the background — no UI interaction required.
  ///
  /// Returns the number of emails successfully sent.
  Future<int> sendEmergencyEmail({
    required List<EmailContact> contacts,
    required String senderName,
    double? latitude,
    double? longitude,
    String? address,
    String triggerSource = 'SOS',
  }) async {
    final username = AppEnv.smtpUsername;
    final password = AppEnv.smtpPassword;

    if (username.isEmpty || password.isEmpty) {
      AppLogger.w(
          'EmailService: SMTP credentials not configured — skipping email alert. '
          'Set SMTP_USERNAME and SMTP_PASSWORD in .env');
      return 0;
    }

    final emailContacts =
        contacts.where((c) => c.email.trim().isNotEmpty).toList();

    if (emailContacts.isEmpty) {
      AppLogger.w('EmailService: no contacts with email addresses — skipping');
      return 0;
    }

    AppLogger.i(
        'EmailService: sending emergency email to ${emailContacts.length} contacts');

    final mapsUrl = (latitude != null && longitude != null)
        ? 'https://maps.google.com/?q=$latitude,$longitude'
        : null;

    final timeStr = DateTime.now().toLocal().toString().split('.').first;

    final subject = '🚨 EMERGENCY ALERT — $senderName needs help NOW';

    final htmlBody = _buildHtmlBody(
      senderName: senderName,
      timeStr: timeStr,
      mapsUrl: mapsUrl,
      address: address,
      triggerSource: triggerSource,
    );

    final plainBody = _buildPlainBody(
      senderName: senderName,
      timeStr: timeStr,
      mapsUrl: mapsUrl,
      address: address,
      triggerSource: triggerSource,
    );

    // Build SMTP server config
    final smtpServer = SmtpServer(
      AppEnv.smtpHost,
      port: AppEnv.smtpPort,
      username: username,
      password: password,
      ssl: AppEnv.smtpPort == 465,
      allowInsecure: false,
    );

    int sentCount = 0;

    for (final contact in emailContacts) {
      try {
        final message = Message()
          ..from = Address(username, AppEnv.smtpFromName)
          ..recipients.add(Address(contact.email.trim(), contact.name))
          ..subject = subject
          ..html = htmlBody
          ..text = plainBody;

        final sendReport = await send(message, smtpServer);
        AppLogger.i(
            'EmailService: email sent to ${contact.email} — ${sendReport.mail.subject}');
        sentCount++;
      } catch (e) {
        AppLogger.w('EmailService: failed to send to ${contact.email}: $e');
        // Continue to next contact even if one fails
      }
    }

    AppLogger.i(
        'EmailService: $sentCount/${emailContacts.length} emails sent successfully');
    return sentCount;
  }

  // ── Message builders ───────────────────────────────────────────────────────

  String _buildHtmlBody({
    required String senderName,
    required String timeStr,
    String? mapsUrl,
    String? address,
    required String triggerSource,
  }) {
    final locationHtml = mapsUrl != null
        ? '''
        <tr>
          <td style="padding:8px 0;color:#6b7280;font-size:14px;">📍 Location</td>
          <td style="padding:8px 0;font-size:14px;">
            <a href="$mapsUrl" style="color:#7c3aed;font-weight:bold;">Open in Google Maps</a>
            ${address != null ? '<br><span style="color:#374151;">$address</span>' : ''}
          </td>
        </tr>'''
        : '''
        <tr>
          <td style="padding:8px 0;color:#6b7280;font-size:14px;">📍 Location</td>
          <td style="padding:8px 0;font-size:14px;color:#ef4444;">Unavailable</td>
        </tr>''';

    return '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;padding:32px 0;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <!-- Header -->
        <tr>
          <td style="background:#dc2626;padding:28px 32px;text-align:center;">
            <div style="font-size:36px;">🚨</div>
            <h1 style="color:#ffffff;margin:8px 0 4px;font-size:24px;font-weight:800;letter-spacing:1px;">EMERGENCY ALERT</h1>
            <p style="color:rgba(255,255,255,0.85);margin:0;font-size:14px;">Sent automatically by SheShield</p>
          </td>
        </tr>
        <!-- Body -->
        <tr>
          <td style="padding:28px 32px;">
            <p style="font-size:16px;color:#111827;margin:0 0 20px;">
              <strong>$senderName</strong> has triggered an emergency SOS alert and may need immediate help.
            </p>
            <table width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #e5e7eb;">
              <tr>
                <td style="padding:8px 0;color:#6b7280;font-size:14px;">⏰ Time</td>
                <td style="padding:8px 0;font-size:14px;color:#374151;font-weight:600;">$timeStr</td>
              </tr>
              <tr style="border-top:1px solid #f3f4f6;">
                <td style="padding:8px 0;color:#6b7280;font-size:14px;">🔔 Trigger</td>
                <td style="padding:8px 0;font-size:14px;color:#374151;">$triggerSource</td>
              </tr>
              <tr style="border-top:1px solid #f3f4f6;">
                $locationHtml
              </tr>
            </table>
            <div style="margin:24px 0;padding:16px;background:#fef2f2;border-radius:10px;border-left:4px solid #dc2626;">
              <p style="margin:0;color:#991b1b;font-size:14px;font-weight:600;">
                Please respond immediately or contact emergency services (112 / 100).
              </p>
            </div>
            ${mapsUrl != null ? '''
            <div style="text-align:center;margin:20px 0;">
              <a href="$mapsUrl" style="display:inline-block;background:#dc2626;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:10px;font-weight:700;font-size:15px;">
                📍 View Live Location
              </a>
            </div>''' : ''}
          </td>
        </tr>
        <!-- Footer -->
        <tr>
          <td style="background:#f9fafb;padding:16px 32px;text-align:center;border-top:1px solid #e5e7eb;">
            <p style="margin:0;color:#9ca3af;font-size:12px;">
              This alert was sent automatically by <strong>SheShield</strong> — Women's Safety App.<br>
              Do not reply to this email.
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>''';
  }

  String _buildPlainBody({
    required String senderName,
    required String timeStr,
    String? mapsUrl,
    String? address,
    required String triggerSource,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 EMERGENCY ALERT — SheShield');
    buffer.writeln('');
    buffer.writeln('$senderName has triggered an emergency SOS alert.');
    buffer.writeln('');
    buffer.writeln('Time: $timeStr');
    buffer.writeln('Trigger: $triggerSource');
    if (mapsUrl != null) {
      buffer.writeln('Location: $mapsUrl');
    }
    if (address != null && address.isNotEmpty) {
      buffer.writeln('Address: $address');
    }
    buffer.writeln('');
    buffer.writeln(
        'Please respond immediately or contact emergency services (112 / 100).');
    buffer.writeln('');
    buffer.writeln('— SheShield Women\'s Safety App');
    return buffer.toString();
  }
}
