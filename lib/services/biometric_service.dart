import 'package:local_auth/local_auth.dart';
import '../core/utils/logger.dart';

/// Wraps local_auth for fingerprint / Face ID authentication.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// Returns true if the device supports biometrics and has enrolled credentials.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      AppLogger.w('BiometricService.isAvailable error: $e');
      return false;
    }
  }

  /// Prompt the user for biometric authentication.
  /// Returns true if authenticated successfully.
  static Future<bool> authenticate({
    String reason = 'Authenticate to access SheShield',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN fallback
          stickyAuth: true,
        ),
      );
    } catch (e) {
      AppLogger.w('BiometricService.authenticate error: $e');
      return false;
    }
  }
}
