import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/listing.dart';
import '../../../providers/discovery_providers.dart';
import '../../../providers/location_providers.dart';
import 'discovery_error_view.dart';
import 'listing_preview_card.dart';

class ListingMapView extends ConsumerStatefulWidget {
  const ListingMapView({super.key});

  @override
  ConsumerState<ListingMapView> createState() => _ListingMapViewState();
}

class _ListingMapViewState extends ConsumerState<ListingMapView> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(nearbyListingsProvider);
    final positionAsync = ref.watch(accountLocationProvider);

    if (positionAsync.isLoading || listingsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = positionAsync.error ?? listingsAsync.error;
    if (error != null) {
      return DiscoveryErrorView(
        error: error,
        onRetry: () {
          ref.invalidate(accountLocationProvider);
          ref.invalidate(nearbyListingsProvider);
        },
      );
    }

    final position = positionAsync.requireValue;
    final listings = listingsAsync.requireValue;

    final listingsWithLocation = listings
        .where((listing) => listing.location != null)
        .toList();

    final markers = listingsWithLocation.map((listing) {
      return Marker(
        markerId: MarkerId(listing.id.toString()),
        position: LatLng(
          listing.location!.latitude,
          listing.location!.longitude,
        ),
        onTap: () =>
            ref.read(selectedListingIdProvider.notifier).state = listing.id,
      );
    }).toSet();

    final selectedId = ref.watch(selectedListingIdProvider);
    final selectedListing = selectedId == null
        ? null
        : listingsWithLocation.cast<Listing?>().firstWhere(
            (listing) => listing?.id == selectedId,
            orElse: () => null,
          );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 13,
          ),
          markers: markers,
          onMapCreated: (controller) => _controller = controller,
          onTap: (_) =>
              ref.read(selectedListingIdProvider.notifier).state = null,
        ),
        if (selectedListing != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ListingPreviewCard(
              listing: selectedListing,
              onClose: () =>
                  ref.read(selectedListingIdProvider.notifier).state = null,
            ),
          ),
      ],
    );
  }
}
