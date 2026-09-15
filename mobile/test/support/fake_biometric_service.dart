import 'package:shobuj_mobile/services/biometric_service.dart';

/// Controllable stand-in for BiometricService — the real one needs a
/// platform channel unavailable in widget tests.
class FakeBiometricService implements BiometricService {
  FakeBiometricService({
    bool available = true,
    bool authenticateSucceeds = true,
  }) : _available = available,
       _authenticateSucceeds = authenticateSucceeds;

  final bool _available;
  final bool _authenticateSucceeds;
  bool authenticateCalled = false;

  @override
  Future<bool> isAvailable() async => _available;

  @override
  Future<bool> authenticate() async {
    authenticateCalled = true;
    return _authenticateSucceeds;
  }
}
