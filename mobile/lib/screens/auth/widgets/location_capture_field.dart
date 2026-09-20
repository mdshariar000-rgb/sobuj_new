import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/location_providers.dart';

/// Shows the device-location status during registration — Shobuj requires a
/// real location on every account (see the backend's NOT NULL, spatially
/// indexed base_location/fuzzy_location columns), so this is a hard
/// prerequisite for signing up, not an optional nicety.
class LocationCaptureField extends ConsumerWidget {
  const LocationCaptureField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(deviceLocationProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            locationAsync.hasError ? Icons.location_off : Icons.my_location,
            color: locationAsync.hasError
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _describe(locationAsync),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (locationAsync.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (locationAsync.hasError)
            TextButton(
              onPressed: () => ref.invalidate(deviceLocationProvider),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  String _describe(AsyncValue<dynamic> locationAsync) {
    if (locationAsync.isLoading) {
      return 'Detecting your location…';
    }

    return switch (locationAsync.error) {
      null => 'Location detected — Shobuj uses this to show you swaps nearby.',
      LocationServiceDisabledException() =>
        'Location services are off. Enable them to sign up.',
      LocationPermissionPermanentlyDeniedException() =>
        'Location permission denied. Enable it for this app in system settings.',
      LocationPermissionDeniedException() =>
        'Location permission is required to sign up.',
      LocationTimeoutException() =>
        'Could not get your location — check your signal and try again.',
      _ => 'Could not detect your location.',
    };
  }
}
