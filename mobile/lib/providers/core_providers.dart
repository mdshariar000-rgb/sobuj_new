import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/biometric_service.dart';
import '../services/dio_factory.dart';
import '../services/secure_storage_service.dart';
import '../services/weather_service.dart';

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
