import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/social_sign_in_service.dart';
import '../services/api_client.dart';
import '../services/biometric_service.dart';
import '../services/dio_factory.dart';
import '../services/secure_storage_service.dart';
import '../services/uk_location_service.dart';
import '../services/weather_service.dart';

final socialSignInServiceProvider = Provider<SocialSignInService>(
  (ref) => SocialSignInService(),
);

/// The admin panel's sign-in settings. Fails closed: no buttons if the
/// server can't be reached.
final socialConfigProvider = FutureProvider<SocialConfig>((ref) async {
  try {
    return await ref.watch(apiClientProvider).socialConfig();
  } catch (_) {
    return SocialConfig.off;
  }
});

/// The sign-in buttons to show on this device.
final availableSocialProvidersProvider = FutureProvider<List<SocialProvider>>((
  ref,
) async {
  final config = await ref.watch(socialConfigProvider.future);
  return ref.watch(socialSignInServiceProvider).availableProviders(config);
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService(FlutterSecureStorage());
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final dioProvider = Provider<Dio>((ref) {
  return buildDio(ref.watch(secureStorageProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

/// A plain, unauthenticated Dio instance for third-party APIs (Open-Meteo)
/// — deliberately not [dioProvider], which attaches this app's own auth
/// interceptors/base URL.
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

/// Same reasoning as [weatherServiceProvider] — postcodes.io is a public,
/// unauthenticated third-party API.
final ukLocationServiceProvider = Provider<UkLocationService>((ref) {
  return UkLocationService();
});
