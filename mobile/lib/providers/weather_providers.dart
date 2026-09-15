import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weather_snapshot.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Real current weather for the signed-in user's approximate location — null
/// (not an error) when they have no location on file, so the UI can prompt
/// for one instead of showing a spurious failure state.
final currentWeatherProvider = FutureProvider.autoDispose<WeatherSnapshot?>((
  ref,
) async {
  final location = ref.watch(authControllerProvider).valueOrNull?.location;
  if (location == null) return null;

  return ref
      .watch(weatherServiceProvider)
      .fetchCurrent(latitude: location.latitude, longitude: location.longitude);
});
