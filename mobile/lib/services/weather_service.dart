import 'package:dio/dio.dart';

import '../models/weather_snapshot.dart';

/// Fetches real current-conditions data from Open-Meteo — a free, no-API-key
/// weather API — rather than fabricating "live" atmosphere/rainfall numbers.
class WeatherService {
  WeatherService([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<WeatherSnapshot> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'current': 'temperature_2m,relative_humidity_2m',
        'daily': 'precipitation_sum',
        'forecast_days': 1,
        'timezone': 'auto',
      },
    );
    return WeatherSnapshot.fromJson(response.data as Map<String, dynamic>);
  }
}
