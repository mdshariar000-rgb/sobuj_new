import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SocialProvider {
  google('Google'),
  apple('Apple');

  const SocialProvider(this.label);

  final String label;

  /// What the API calls it ("google" / "apple").
  String get value => name;

  static SocialProvider? fromValue(String value) =>
      SocialProvider.values.where((p) => p.value == value).firstOrNull;
}

/// The public sign-in settings from the admin panel (GET /config/social).
class SocialConfig {
  const SocialConfig({
    this.googleEnabled = false,
    this.googleIosClientId,
    this.googleServerClientId,
    this.appleEnabled = false,
  });

  final bool googleEnabled;
  final String? googleIosClientId;

  /// The Web client: Android asks Google for a token issued to it.
  final String? googleServerClientId;
  final bool appleEnabled;

  static const off = SocialConfig();

  factory SocialConfig.fromJson(Map<String, dynamic> json) {
    final google = json['google'] as Map<String, dynamic>? ?? const {};
    final apple = json['apple'] as Map<String, dynamic>? ?? const {};
    return SocialConfig(
      googleEnabled: google['enabled'] as bool? ?? false,
      googleIosClientId: google['ios_client_id'] as String?,
      googleServerClientId: google['server_client_id'] as String?,
      appleEnabled: apple['enabled'] as bool? ?? false,
    );
  }
}

/// A signed ID token from Google or Apple, for the backend to check
/// (POST /auth/social).
class SocialCredential {
  const SocialCredential({
    required this.provider,
    required this.idToken,
    this.nonce,
    this.name,
    this.authorizationCode,
  });

  final SocialProvider provider;
  final String idToken;

  /// Apple: the raw nonce whose SHA-256 is inside [idToken].
  final String? nonce;

  /// Apple shares the name only on the very first sign-in, so it's kept
  /// here for the "finish signing up" step.
  final String? name;

  /// Apple: a one-time code — sent when deleting the account, so the
  /// server can revoke the Apple link.
  final String? authorizationCode;
}

/// Shown as-is when Google or Apple sign-in fails (not when it's cancelled).
class SocialSignInException implements Exception {
  const SocialSignInException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The Google and Apple sign-in sheets. Each returns a credential, or null
/// when the user cancels. Nothing is kept signed in on the device — the
/// token is handed to our backend, which issues its own session.
class SocialSignInService {
  static const _appInfo = MethodChannel('shobuj/app_info');

  String? _googleClientKey;

  /// Which buttons to show: switched on in the admin panel and possible on
  /// this device. Google on iPhone also needs its URL scheme in the app's
  /// Info.plist — without it Google's SDK crashes, so it stays hidden.
  Future<List<SocialProvider>> availableProviders(SocialConfig config) async {
    final available = <SocialProvider>[];
    if (config.appleEnabled && Platform.isIOS) {
      available.add(SocialProvider.apple);
    }
    if (config.googleEnabled) {
      if (Platform.isAndroid &&
          (config.googleServerClientId ?? '').isNotEmpty) {
        available.add(SocialProvider.google);
      } else if (Platform.isIOS &&
          (config.googleIosClientId ?? '').isNotEmpty &&
          await _hasUrlScheme(_reversed(config.googleIosClientId!))) {
        available.add(SocialProvider.google);
      }
    }
    return available;
  }

  Future<SocialCredential?> signIn(
    SocialProvider provider,
    SocialConfig config,
  ) => switch (provider) {
    SocialProvider.google => _google(config),
    SocialProvider.apple => _apple(),
  };

  /// "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc".
  static String _reversed(String clientId) =>
      clientId.split('.').reversed.join('.');

  Future<bool> _hasUrlScheme(String scheme) async {
    try {
      final schemes = await _appInfo.invokeListMethod<String>('urlSchemes');
      return schemes?.contains(scheme) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<SocialCredential?> _google(SocialConfig config) async {
    final google = GoogleSignIn.instance;
    try {
      final clientId = Platform.isIOS ? config.googleIosClientId : null;
      final serverClientId = (config.googleServerClientId ?? '').isEmpty
          ? null
          : config.googleServerClientId;
      final key = '$clientId|$serverClientId';
      // initialize() may only run once per app launch.
      if (_googleClientKey == null) {
        await google.initialize(
          clientId: clientId,
          serverClientId: serverClientId,
        );
        _googleClientKey = key;
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      // Next time, let them pick an account again.
      await google.signOut();
      if (idToken == null) {
        throw const SocialSignInException(
          "Google sign-in didn't work. Please try again.",
        );
      }
      return SocialCredential(
        provider: SocialProvider.google,
        idToken: idToken,
        name: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const SocialSignInException(
        "Google sign-in didn't work. Please try again.",
      );
    }
  }

  Future<SocialCredential?> _apple() async {
    final rawNonce = _randomNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const SocialSignInException(
          "Apple sign-in didn't work. Please try again.",
        );
      }
      final name = [credential.givenName, credential.familyName]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');
      return SocialCredential(
        provider: SocialProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
        name: name.isEmpty ? null : name,
        authorizationCode: credential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw const SocialSignInException(
        "Apple sign-in didn't work. Please try again.",
      );
    }
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
