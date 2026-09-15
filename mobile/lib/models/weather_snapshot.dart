import 'package:flutter/foundation.dart';

/// A real current-conditions reading from Open-Meteo (open-meteo.com, no API
/// key required) for the signed-in user's approximate (fuzzed) location.
@immutable
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.humidityPercent,
    required this.rainfallTodayMm,
  });

  final double temperatureC;
  final double humidityPercent;
  final double rainfallTodayMm;

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    final precipitationSums = (daily?['precipitation_sum'] as List?)
        ?.cast<num>();

    return WeatherSnapshot(
      temperatureC: (current['temperature_2m'] as num).toDouble(),
      humidityPercent: (current['relative_humidity_2m'] as num).toDouble(),
      rainfallTodayMm: (precipitationSums != null && precipitationSums.isNotEmpty)
          ? precipitationSums.first.toDouble()
          : 0,
    );
  }
}
