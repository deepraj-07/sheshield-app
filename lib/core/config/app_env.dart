import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AppEnv centralizes all environment variable access.
///
/// No circular imports — Firebase fallback values are hardcoded here directly.
/// firebase_options.dart does NOT import this file; it uses its own constants.
/// This file does NOT import firebase_options.dart.
class AppEnv {
  AppEnv._();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      if (kDebugMode) {
        debugPrint('AppEnv: .env loaded (${dotenv.env.length} keys)');
        // Log which SMTP keys are present (values hidden)
        final smtpKeys = [
          'SMTP_HOST',
          'SMTP_PORT',
          'SMTP_USERNAME',
          'SMTP_PASSWORD',
          'SMTP_FROM_NAME'
        ];
        for (final k in smtpKeys) {
          debugPrint(
              'AppEnv: $k = ${dotenv.env.containsKey(k) ? "✓ set" : "✗ missing"}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppEnv: .env load failed — $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SMTP Email
  // ---------------------------------------------------------------------------

  static String get smtpHost => _optional('SMTP_HOST', 'smtp.gmail.com');
  static int get smtpPort => int.tryParse(_optional('SMTP_PORT', '587')) ?? 587;
  static String get smtpUsername => _optional('SMTP_USERNAME', '');
  static String get smtpPassword => _optional('SMTP_PASSWORD', '');
  static String get smtpFromName =>
      _optional('SMTP_FROM_NAME', 'SheShield Emergency');

  // ---------------------------------------------------------------------------
  // Google Maps
  // ---------------------------------------------------------------------------

  static String get googleMapsApiKey => _optional('GOOGLE_MAPS_API_KEY', '');

  // ---------------------------------------------------------------------------
  // FCM
  // ---------------------------------------------------------------------------

  static String get fcmServerKey => _optional('FCM_SERVER_KEY', '');

  // ---------------------------------------------------------------------------
  // Stealth mode
  // ---------------------------------------------------------------------------

  static String get stealthModeCode => _optional('STEALTH_MODE_CODE', '0000');

  // ---------------------------------------------------------------------------
  // External APIs
  // ---------------------------------------------------------------------------

  static String get osmOverpassApiUrl => _optional(
      'OSM_OVERPASS_API_URL', 'https://overpass-api.de/api/interpreter');

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  static String _optional(String key, String fallback) {
    final value = dotenv.env[key];
    return (value != null && value.isNotEmpty) ? value : fallback;
  }
}
