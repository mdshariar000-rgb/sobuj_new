import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Location permission was denied (once, not permanently) or the user hasn't
/// been asked yet and declined the prompt.
class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();

  @override
  String toString() => 'Location permission was denied.';
}

/// Location permission was denied permanently ("don't ask again") — the app
/// must send the user to system settings to recover.
class LocationPermissionPermanentlyDeniedException implements Exception {
  const LocationPermissionPermanentlyDeniedException();

  @override
  String toString() =>
      'Location permission is permanently denied. Enable it in system settings.';
}

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();

  @override
  String toString() => 'Location services are turned off on this device.';
}

/// The device's current GPS position. Discovery search radius is centered on
/// this — the fuzzing that protects *other* users' locations happens
/// server-side; this is simply "where am I right now".
final deviceLocationProvider = FutureProvider.autoDispose<Position>((
  ref,
) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationServiceDisabledException();
  }

  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    throw const LocationPermissionPermanentlyDeniedException();
  }

  if (permission == LocationPermission.denied) {
    throw const LocationPermissionDeniedException();
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  );
});
