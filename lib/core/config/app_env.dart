import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../firebase_options.dart';

/// AppEnv centralizes all environment variable access.
///
/// ## How it works
///
/// In local/debug builds, `AppEnv.load()` reads a `.env` file from the
/// **filesystem** (not from Flutter assets). The file must exist at the
/// project root when running `flutter run` from that directory.
///
/// In release/CI builds where no `.env` file is present, `load()` silently
/// continues and every getter falls back to its hardcoded default. The app
/// never crashes due to a missing `.env`.
///
/// ## Security model
///
/// `.env` is NEVER declared as a Flutter asset (it would be bundled into the
/// APK and readable by anyone who unpacks it). It is only used as a local
/// developer convenience to override values during development.
///
/// Firebase client config values (apiKey, appId, etc.) are NOT secrets —
/// they are the same values in the committed `google-services.json`. Security
/// is enforced by Firebase Security Rules on the server side.
///
/// ## Usage
/// ```dart
/// await AppEnv.load();   // once in main(), before Firebase.initializeApp()
/// final key = AppEnv.googleMapsApiKey;
/// ```
class AppEnv {
  AppEnv._(); // static-only — not instantiable

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Attempts to load `.env` from the local filesystem.
  ///
  /// Silently succeeds when the file is absent (release builds, CI, devices
  /// without a local `.env`). All getters fall back to their hardcoded
  /// defaults in that case.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      if (kDebugMode) {
        debugPrint('AppEnv: .env loaded (${dotenv.env.length} keys)');
      }
    } catch (_) {
      // .env is optional. Missing file is expected in release/CI builds.
      if (kDebugMode) {
        debugPrint('AppEnv: no .env file found — using built-in defaults.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Firebase (Android)
  //
  // Fallbacks are the same values in google-services.json — safe to hardcode.
  // ---------------------------------------------------------------------------

  static String get firebaseApiKey =>
      _optional('FIREBASE_API_KEY', DefaultFirebaseOptions.defaultApiKey);

  static String get firebaseAppId =>
      _optional('FIREBASE_APP_ID', DefaultFirebaseOptions.defaultAppId);

  static String get firebaseMessagingSenderId => _optional(
      'FIREBASE_MESSAGING_SENDER_ID',
      DefaultFirebaseOptions.defaultMessagingSenderId);

  static String get firebaseProjectId =>
      _optional('FIREBASE_PROJECT_ID', DefaultFirebaseOptions.defaultProjectId);

  static String get firebaseStorageBucket => _optional(
      'FIREBASE_STORAGE_BUCKET', DefaultFirebaseOptions.defaultStorageBucket);

  // ---------------------------------------------------------------------------
  // Google Maps
  // ---------------------------------------------------------------------------

  /// Google Maps API key. Empty string disables map features gracefully.
  static String get googleMapsApiKey => _optional('GOOGLE_MAPS_API_KEY', '');

  // ---------------------------------------------------------------------------
  // FCM
  // ---------------------------------------------------------------------------

  /// Legacy FCM server key for direct push delivery.
  /// Empty → app falls back to Firestore notification queue (Cloud Functions).
  static String get fcmServerKey => _optional('FCM_SERVER_KEY', '');

  // ---------------------------------------------------------------------------
  // Stealth mode
  // ---------------------------------------------------------------------------

  /// Secret tap code that activates stealth mode.
  static String get stealthModeCode => _optional('STEALTH_MODE_CODE', '0000');

  // ---------------------------------------------------------------------------
  // External APIs
  // ---------------------------------------------------------------------------

  /// OpenStreetMap Overpass API endpoint.
  static String get osmOverpassApiUrl => _optional(
      'OSM_OVERPASS_API_URL', 'https://overpass-api.de/api/interpreter');

  // ---------------------------------------------------------------------------
  // Internal helper
  // ---------------------------------------------------------------------------

  /// Returns the `.env` value for [key] when present and non-empty,
  /// otherwise returns [fallback].
  static String _optional(String key, String fallback) {
    final value = dotenv.env[key];
    return (value != null && value.isNotEmpty) ? value : fallback;
  }
}
