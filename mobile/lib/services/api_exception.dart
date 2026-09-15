import 'package:dio/dio.dart';

/// Typed error surface for the whole app — screens should only ever need to
/// catch this, never Dio's own exception types.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors,
  });

  final String message;
  final int? statusCode;

  /// Laravel's 422 validation error shape, keyed by field name.
  final Map<String, List<String>>? fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  /// Also covers a suspended account being rejected at login or blocked from
  /// a protected route — see EnsureUserIsNotSuspended on the backend.
  bool get isForbidden => statusCode == 403;

  bool get isValidationError => statusCode == 422;

  factory ApiException.fromDioException(DioException exception) {
    final response = exception.response;

    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        message: 'The request timed out. Please try again.',
      );
    }

    if (exception.type == DioExceptionType.connectionError) {
      return const ApiException(
        message: 'Could not reach the server. Check your connection.',
      );
    }

    final data = response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String? ?? 'Something went wrong.';
      final rawErrors = data['errors'];

      Map<String, List<String>>? fieldErrors;
      if (rawErrors is Map) {
        fieldErrors = rawErrors.map(
          (key, value) =>
              MapEntry(key as String, List<String>.from(value as List)),
        );
      }

      return ApiException(
        message: message,
        statusCode: response?.statusCode,
        fieldErrors: fieldErrors,
      );
    }

    return ApiException(
      message: exception.message ?? 'Something went wrong.',
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
