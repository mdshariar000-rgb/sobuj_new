import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/uk_address.dart';
import '../models/enums.dart';
import '../services/social_sign_in_service.dart';
import '../services/api_client.dart';
import '../services/biometric_service.dart';
import '../services/push_notification_service.dart';
import '../services/secure_storage_service.dart';
import 'core_providers.dart';

/// The whole app's auth state: `AsyncValue<AppUser?>` where `null` means
/// signed out. `loading` only ever represents the *initial* session restore
/// on app start — login/register failures are surfaced as thrown
/// [ApiException]s to the calling screen instead of mutating this state, so a
/// failed login attempt never flashes the rest of the app into an error/
/// loading view.
class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  AuthController(
    this._apiClient,
    this._secureStorage,
    this._biometricService,
    this._pushService,
  ) : super(const AsyncValue.loading()) {
    _restoreSession();
  }

  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;
  final BiometricService _biometricService;
  final PushNotificationService _pushService;

  Future<void> _restoreSession() async {
    final token = await _secureStorage.readToken();

    if (token == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final user = await _apiClient.me();
      state = AsyncValue.data(user);
      _pushService.requestPermissionAndRegister(_apiClient);
    } catch (_) {
      // Token is missing, expired, revoked, or the account is suspended —
      // either way there's nothing useful to restore. Fall back to signed out
      // rather than surfacing a restore error the user can't act on.
      await _secureStorage.clearToken();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _apiClient.login(email: email, password: password);
    await _secureStorage.saveToken(result.token);
    state = AsyncValue.data(result.user);
    _pushService.requestPermissionAndRegister(_apiClient);
  }

  /// "Sign in with Google / Apple". Signs an existing account in and
  /// returns null — or returns [SocialNeedsSignup] for a new person, whose
  /// address [completeSocialSignup] then sends.
  Future<SocialNeedsSignup?> signInWithSocial(
    SocialCredential credential,
  ) async {
    final result = await _apiClient.socialLogin(
      provider: credential.provider.value,
      idToken: credential.idToken,
      nonce: credential.nonce,
      name: credential.name,
    );
    switch (result) {
      case SocialNeedsSignup():
        return result;
      case SocialSignedIn(:final auth):
        await _signedIn(auth);
        return null;
    }
  }

  Future<void> completeSocialSignup({
    required SocialCredential credential,
    required String name,
    required double latitude,
    required double longitude,
    String? locationLabel,
    required UkAddress address,
  }) async {
    final result = await _apiClient.socialLogin(
      provider: credential.provider.value,
      idToken: credential.idToken,
      nonce: credential.nonce,
      name: name,
      latitude: latitude,
      longitude: longitude,
      locationLabel: locationLabel,
      address: address,
    );
    if (result case SocialSignedIn(:final auth)) {
      await _signedIn(auth);
    }
  }

  Future<void> _signedIn(AuthResult result) async {
    await _secureStorage.saveToken(result.token);
    state = AsyncValue.data(result.user);
    _pushService.requestPermissionAndRegister(_apiClient);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required double latitude,
    required double longitude,
    String? locationLabel,
    String? experienceLevel,
    String? growingSetup,
    List<String> growingInterests = const [],
    UkAddress? address,
  }) async {
    final result = await _apiClient.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      latitude: latitude,
      longitude: longitude,
      locationLabel: locationLabel,
      experienceLevel: experienceLevel,
      growingSetup: growingSetup,
      growingInterests: growingInterests,
      address: address,
    );
    await _secureStorage.saveToken(result.token);
    state = AsyncValue.data(result.user);
    _pushService.requestPermissionAndRegister(_apiClient);
  }

  Future<void> logout() async {
    // Best-effort, and must happen while the auth token is still valid —
    // unregistering the device is itself an authenticated call.
    await _pushService.unregister(_apiClient);

    try {
      await _apiClient.logout();
    } catch (_) {
      // Best-effort: still sign out locally even if the network call fails
      // (e.g. no connectivity, or the token was already revoked server-side).
    }
    await _secureStorage.clearToken();
    state = const AsyncValue.data(null);
  }

  /// Permanently deletes the account on the server, then signs out locally.
  /// Throws [ApiException] (wrong password, or a server-side failure) without
  /// touching local session state, so the account stays signed in on failure.
  /// No device-token unregister here: deleting the account cascades its
  /// device tokens away server-side, and that call would need a token that no
  /// longer exists.
  Future<void> deleteAccount({
    String? password,
    SocialCredential? confirmWith,
  }) async {
    await _apiClient.deleteAccount(
      password: password,
      provider: confirmWith?.provider.value,
      idToken: confirmWith?.idToken,
      nonce: confirmWith?.nonce,
      authorizationCode: confirmWith?.authorizationCode,
    );
    await _secureStorage.clearBiometricCredentials();
    await _secureStorage.clearToken();
    state = const AsyncValue.data(null);
  }

  /// Updates the signed-in user's own profile and refreshes app-wide state
  /// with the server's response, so every screen watching this provider
  /// (Profile, listing cards, post authorship, etc.) reflects the change
  /// immediately without a manual refresh.
  Future<void> updateProfile({
    String? name,
    String? username,
    String? bio,
    String? phone,
    String? locationLabel,
    List<String>? growingInterests,
    bool? showHandoverRadius,
    ExperienceLevel? experienceLevel,
    GrowingSetup? growingSetup,
    File? avatar,
    File? coverPhoto,
    UkAddress? address,
    double? latitude,
    double? longitude,
  }) async {
    final updated = await _apiClient.updateProfile(
      name: name,
      username: username,
      bio: bio,
      phone: phone,
      locationLabel: locationLabel,
      growingInterests: growingInterests,
      showHandoverRadius: showHandoverRadius,
      experienceLevel: experienceLevel,
      growingSetup: growingSetup,
      avatar: avatar,
      coverPhoto: coverPhoto,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    state = AsyncValue.data(updated);
  }

  /// Re-fetches the signed-in user's own record (posts/active-listings
  /// counts included) — used by the Profile screen's pull-to-refresh.
  Future<void> refresh() async {
    final user = await _apiClient.me();
    state = AsyncValue.data(user);
  }

  /// Whether the Login screen should show the biometric quick-login button
  /// — needs both a device that supports it and a previously-saved
  /// "Remember me" credential to replay.
  Future<bool> checkBiometricLoginAvailable() async {
    final deviceSupportsIt = await _biometricService.isAvailable();
    final credentials = await _secureStorage.readBiometricCredentials();
    return deviceSupportsIt && credentials != null;
  }

  /// Prompts the device biometric/PIN dialog, then replays a normal
  /// login() with the credentials saved from a prior "Remember me" login —
  /// there's no biometric-specific auth on the backend, this only gates
  /// re-use of an already-successful password login. Returns false (rather
  /// than throwing) on a declined/failed biometric prompt, since that's a
  /// routine outcome, not an error the caller needs to display specially;
  /// an actual login failure still throws ApiException as normal.
  Future<bool> loginWithBiometrics() async {
    final credentials = await _secureStorage.readBiometricCredentials();
    if (credentials == null) return false;

    final authenticated = await _biometricService.authenticate();
    if (!authenticated) return false;

    await login(email: credentials.email, password: credentials.password);
    return true;
  }

  Future<void> saveBiometricCredentials({
    required String email,
    required String password,
  }) {
    return _secureStorage.saveBiometricCredentials(
      email: email,
      password: password,
    );
  }

  Future<void> clearBiometricCredentials() {
    return _secureStorage.clearBiometricCredentials();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
      return AuthController(
        ref.watch(apiClientProvider),
        ref.watch(secureStorageProvider),
        ref.watch(biometricServiceProvider),
        ref.watch(pushNotificationServiceProvider),
      );
    });
