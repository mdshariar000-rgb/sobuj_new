import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/providers/auth_providers.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/api_exception.dart';
import 'package:shobuj_mobile/services/biometric_service.dart';
import 'package:shobuj_mobile/services/secure_storage_service.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockBiometricService extends Mock implements BiometricService {}

AppUser _buildUser({int id = 1}) {
  return AppUser(
    id: id,
    name: 'Rina',
    ratingAvg: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late MockApiClient apiClient;
  late MockSecureStorageService secureStorage;
  late MockBiometricService biometricService;

  setUp(() {
    apiClient = MockApiClient();
    secureStorage = MockSecureStorageService();
    biometricService = MockBiometricService();
  });

  group('session restore (on construction)', () {
    test(
      'with no stored token, settles as signed out without calling the API',
      () async {
        when(() => secureStorage.readToken()).thenAnswer((_) async => null);

        final controller = AuthController(
          apiClient,
          secureStorage,
          biometricService,
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.value, isNull);
        verifyNever(() => apiClient.me());
      },
    );

    test('with a valid stored token, restores the user via /auth/me', () async {
      final user = _buildUser();
      when(
        () => secureStorage.readToken(),
      ).thenAnswer((_) async => 'stored-token');
      when(() => apiClient.me()).thenAnswer((_) async => user);

      final controller = AuthController(
        apiClient,
        secureStorage,
        biometricService,
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value, user);
    });

    test(
      'with an invalid/expired stored token, clears it and settles as signed out',
      () async {
        when(
          () => secureStorage.readToken(),
        ).thenAnswer((_) async => 'stale-token');
        when(() => apiClient.me()).thenThrow(
          const ApiException(message: 'Unauthenticated.', statusCode: 401),
        );
        when(() => secureStorage.clearToken()).thenAnswer((_) async {});

        final controller = AuthController(
          apiClient,
          secureStorage,
          biometricService,
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.value, isNull);
        verify(() => secureStorage.clearToken()).called(1);
      },
    );
  });

  group('login', () {
    test(
      'on success, saves the token and updates state to the returned user',
      () async {
        when(() => secureStorage.readToken()).thenAnswer((_) async => null);
        final controller = AuthController(
          apiClient,
          secureStorage,
          biometricService,
        );
        await Future<void>.delayed(Duration.zero);

        final user = _buildUser();
        when(
          () => apiClient.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => AuthResult(user: user, token: 'new-token'));
        when(
          () => secureStorage.saveToken('new-token'),
        ).thenAnswer((_) async {});

        await controller.login(
          email: 'rina@example.com',
          password: 'password123',
        );

        expect(controller.state.value, user);
        verify(() => secureStorage.saveToken('new-token')).called(1);
      },
    );

    test(
      'on failure, rethrows and leaves the previous state untouched',
      () async {
        when(() => secureStorage.readToken()).thenAnswer((_) async => null);
        final controller = AuthController(
          apiClient,
          secureStorage,
          biometricService,
        );
        await Future<void>.delayed(Duration.zero);

        when(
          () => apiClient.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiException(
            message: 'The provided credentials are incorrect.',
            statusCode: 422,
          ),
        );

        await expectLater(
          controller.login(email: 'rina@example.com', password: 'wrong'),
          throwsA(isA<ApiException>()),
        );

        // Still signed out — a failed login must never leave the app in a
        // loading/error limbo, only ever a clean unauthenticated state.
        expect(controller.state.value, isNull);
        verifyNever(() => secureStorage.saveToken(any()));
      },
    );
  });

  group('logout', () {
    test('clears the token and state even if the API call fails', () async {
      final user = _buildUser();
      when(() => secureStorage.readToken()).thenAnswer((_) async => 'token');
      when(() => apiClient.me()).thenAnswer((_) async => user);
      final controller = AuthController(
        apiClient,
        secureStorage,
        biometricService,
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.value, user);

      when(
        () => apiClient.logout(),
      ).thenThrow(const ApiException(message: 'Network error.'));
      when(() => secureStorage.clearToken()).thenAnswer((_) async {});

      await controller.logout();

      expect(controller.state.value, isNull);
      verify(() => secureStorage.clearToken()).called(1);
    });
  });
}
