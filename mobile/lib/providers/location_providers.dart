import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// A fresh GPS fix can take many seconds on real hardware (cold start, weak
/// indoor signal) — this caps how long [deviceLocationProvider] waits for
/// one before giving up, so a location-gated screen never hangs forever.
const _freshFixTimeLimit = Duration(seconds: 15);

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

/// A fresh GPS fix didn't arrive within [_freshFixTimeLimit] and no cached
/// last-known position was available to fall back to either (e.g. a brand
/// new device/install with weak signal).
class LocationTimeoutException implements Exception {
  const LocationTimeoutException();

  @override
  String toString() =>
      'Could not get your location — check your signal and try again.';
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

  // A fresh GPS fix (below) can take anywhere from a couple of seconds to
  // well over 30s on real hardware — indoors, a cold GPS start, or just a
  // weak signal. Every location-gated screen (Marketplace search,
  // registration) used to block on that every single time it opened, which
  // is what made the app feel like it was hanging. The OS keeps a cached
  // "last known" position from the last successful fix (by this app or any
  // other app on the device) that reads instantly with no hardware wait —
  // stale by however long ago that was, but "roughly where I already know
  // I am" beats a blank loading screen, and callers that need an accurate
  // fix for something like registration still get a real fresh one below
  // when no cached position exists yet (e.g. a brand new install).
  final lastKnown = await Geolocator.getLastKnownPosition();
  if (lastKnown != null) {
    return lastKnown;
  }

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _freshFixTimeLimit,
      ),
    );
  } on TimeoutException {
    throw const LocationTimeoutException();
  }
});
