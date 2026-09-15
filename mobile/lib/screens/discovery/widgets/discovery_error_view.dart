import 'package:flutter/material.dart';

import '../../../providers/location_providers.dart';
import '../../../services/api_exception.dart';

/// Turns whatever error nearbyListingsProvider/deviceLocationProvider throws
/// into a message a user can actually act on, with a retry button.
class DiscoveryErrorView extends StatelessWidget {
  const DiscoveryErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = _describe(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String) _describe(Object error) {
    return switch (error) {
      LocationServiceDisabledException() => (
        Icons.location_off,
        'Location services are turned off. Enable them to discover nearby listings.',
      ),
      LocationPermissionPermanentlyDeniedException() => (
        Icons.location_disabled,
        'Location permission is permanently denied. Enable it for this app in your device settings.',
      ),
      LocationPermissionDeniedException() => (
        Icons.location_disabled,
        'Location permission is required to find listings near you.',
      ),
      ApiException(:final message) => (Icons.cloud_off, message),
      _ => (Icons.error_outline, 'Something went wrong. Please try again.'),
    };
  }
}
