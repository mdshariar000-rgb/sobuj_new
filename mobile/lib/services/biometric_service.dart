import 'package:local_auth/local_auth.dart';

/// Thin wrapper around local_auth — not available on web (no browser
/// biometric API for this plugin), so [isAvailable] returning false there is
/// expected, not an error condition.
class BiometricService {
  BiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the OS biometric (or device PIN/pattern, since biometricOnly is
  /// false) dialog. Returns false on failure/cancellation rather than
  /// throwing — callers treat "not authenticated" as the only outcome that
  /// matters, not the specific reason.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Sign in to Agro Hub',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
