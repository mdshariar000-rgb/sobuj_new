import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'secure_storage_service.dart';

/// Builds the single Dio instance the app should use for every backend call.
/// Kept separate from ApiClient so tests can construct an ApiClient around a
/// Dio with a mock adapter instead of a real network stack.
Dio buildDio(SecureStorageService secureStorage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorage.readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}
