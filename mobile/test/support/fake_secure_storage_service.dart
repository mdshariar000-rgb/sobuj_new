import 'package:shobuj_mobile/services/secure_storage_service.dart';

/// In-memory stand-in for SecureStorageService — the real implementation
/// needs a platform channel that isn't available in widget tests.
class FakeSecureStorageService implements SecureStorageService {
  String? _token;
  String? _biometricEmail;
  String? _biometricPassword;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;

  @override
  Future<void> saveBiometricCredentials({
    required String email,
    required String password,
  }) async {
    _biometricEmail = email;
    _biometricPassword = password;
  }

  @override
  Future<({String email, String password})?> readBiometricCredentials() async {
    if (_biometricEmail == null || _biometricPassword == null) return null;
    return (email: _biometricEmail!, password: _biometricPassword!);
  }

  final _aiConsentUserIds = <int>{};

  @override
  Future<bool> readAiConsent(int userId) async =>
      _aiConsentUserIds.contains(userId);

  @override
  Future<void> saveAiConsent(int userId) async => _aiConsentUserIds.add(userId);

  @override
  Future<void> clearBiometricCredentials() async {
    _biometricEmail = null;
    _biometricPassword = null;
  }
}
