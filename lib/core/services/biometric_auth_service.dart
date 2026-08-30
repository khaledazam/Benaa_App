import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if hardware supports biometrics & device is secured
  static Future<bool> isBiometricsAvailable() async {
    if (kIsWeb) return false;
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint("Error checking biometrics availability: $e");
      return false;
    }
  }

  /// Get list of available biometric types (fingerprint, face, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint("Error getting available biometrics: $e");
      return [];
    }
  }

  /// Prompt biometrics authentication dialog (Fingerprint / Face ID)
  static Future<bool> authenticate({
    String reason = 'يرجى تأكيد بصمة الإصبع أو الوجه للمتابعة والوصول للمستودع',
  }) async {
    if (kIsWeb) return true; // Bypass on web demo
    try {
      final bool available = await isBiometricsAvailable();
      if (!available) return true; // If device has no biometrics configured, allow access

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Biometric authentication platform error: $e");
      return false;
    } catch (e) {
      debugPrint("Biometric authentication failed: $e");
      return false;
    }
  }
}
