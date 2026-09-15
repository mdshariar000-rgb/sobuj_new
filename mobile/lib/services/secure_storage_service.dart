import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum bearer token in the platform keychain/keystore —
/// never in SharedPreferences, which is unencrypted.
class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _biometricEmailKey = 'biometric_email';
  static const _biometricPasswordKey = 'biometric_password';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// Credentials saved when a user opts into "Remember me" at login, so the
  /// Face ID/Fingerprint button on Login can silently replay a real login
  /// call after the biometric prompt succeeds — there's no separate
  /// biometric-specific auth on the backend, this just gates re-use of the
  /// same email/password. Kept in the same OS-encrypted store as the auth
  /// token (Keystore/Keychain), not SharedPreferences.
  Future<void> saveBiometricCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _biometricEmailKey, value: email);
    await _storage.write(key: _biometricPasswordKey, value: password);
  }

  /// Null when no credentials have been saved (biometric quick-login isn't
  /// set up yet, or was cleared).
  Future<({String email, String password})?> readBiometricCredentials() async {
    final email = await _storage.read(key: _biometricEmailKey);
    final password = await _storage.read(key: _biometricPasswordKey);

    if (email == null || password == null) return null;

    return (email: email, password: password);
  }

  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _biometricEmailKey);
    await _storage.delete(key: _biometricPasswordKey);
  }
}
