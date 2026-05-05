import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;

import 'core/config/app_env.dart';

/// Firebase configuration for different platforms.
///
/// The hardcoded values below are the same client-side identifiers that
/// `flutterfire configure` writes into this file and that already exist in
/// the committed `android/app/google-services.json`. They are NOT secrets —
/// Firebase client config is designed to be public (security is enforced by
/// Firebase Security Rules, not by hiding these values).
///
/// AppEnv overrides are supported: if a matching key exists in `.env` it
/// takes precedence, otherwise the hardcoded default is used. This means
/// the app works correctly in all environments:
///   • Local dev  — .env overrides (if present)
///   • CI / prod  — hardcoded defaults (no .env needed)
///   • APK        — hardcoded defaults (.env is NOT bundled)
///
/// Regenerate via: `flutterfire configure`
class DefaultFirebaseOptions {
  // ---------------------------------------------------------------------------
  // Hardcoded defaults — safe to commit (client-side only, not admin/server)
  // ---------------------------------------------------------------------------
  static const String _apiKey =
      'AIzaSyC9c-ngIOMfNVq91c2PHOLotcz7bud0fCg';
  static const String _appId =
      '1:612192598689:android:940f5cc4630eb337d90ee0';
  static const String _messagingSenderId = '612192598689';
  static const String _projectId = 'sheshield-bd387';
  static const String _storageBucket = 'sheshield-bd387.firebasestorage.app';

  // ---------------------------------------------------------------------------
  // Platform selector
  // ---------------------------------------------------------------------------

  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) return android;
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform.',
    );
  }

  /// Android Firebase options.
  /// AppEnv values take precedence when present; hardcoded defaults are the
  /// fallback so Firebase init never fails due to a missing .env file.
  static FirebaseOptions get android => FirebaseOptions(
        apiKey: AppEnv.firebaseApiKey,
        appId: AppEnv.firebaseAppId,
        messagingSenderId: AppEnv.firebaseMessagingSenderId,
        projectId: AppEnv.firebaseProjectId,
        storageBucket: AppEnv.firebaseStorageBucket,
      );

  // Expose defaults so AppEnv can use them as fallbacks.
  static String get defaultApiKey => _apiKey;
  static String get defaultAppId => _appId;
  static String get defaultMessagingSenderId => _messagingSenderId;
  static String get defaultProjectId => _projectId;
  static String get defaultStorageBucket => _storageBucket;
}
