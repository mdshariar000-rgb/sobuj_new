import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/api_client.dart';
import '../discovery/listing_detail_screen.dart';
import '../discovery/seller_profile_screen.dart';
import '../discovery/swap_offer_thread_screen.dart';
import '../groups/group_chat_screen.dart';
import '../home/post_detail_screen.dart';

/// The single place that maps a notification's `type` + `data` payload to
/// the real screen it's about — used both by [NotificationsScreen] (tapping
/// a row in the inbox) and PushNotificationService (tapping a system tray
/// notification while backgrounded/killed, from outside any widget's own
/// BuildContext), so the routing logic only exists once. Takes a plain
/// [ApiClient] rather than a WidgetRef so it works the same from a widget
/// (`ref.read(apiClientProvider)`) or from a top-level ProviderContainer
/// (`container.read(apiClientProvider)`) in main.dart.
///
/// [data] accepts either the in-app inbox's real JSON (ids as real ints)
/// or FCM's data payload (every value stringified, since that's an FCM
/// requirement) — ids are parsed leniently either way.
///
/// Returns true if it successfully navigated to a real screen.
Future<bool> openNotificationDeepLink(
  BuildContext context,
  ApiClient apiClient,
  AppNotification notification,
) {
  return _openDeepLink(
    context,
    apiClient,
    notification.type,
    notification.data,
  );
}

Future<bool> openNotificationDataDeepLink(
  BuildContext context,
  ApiClient apiClient,
  Map<String, dynamic> data,
) {
  final type = data['type'] as String?;
  if (type == null) return Future.value(false);
  return _openDeepLink(context, apiClient, type, data);
}

Future<bool> _openDeepLink(
  BuildContext context,
  ApiClient apiClient,
  String type,
  Map<String, dynamic>? data,
) async {
  try {
    switch (type) {
      case 'post_liked':
      case 'post_commented':
      case 'post_shared':
      case 'comment_replied':
        final postId = _parseId(data?['post_id']);
        if (postId == null) return false;
        final post = await apiClient.post(postId);
        if (!context.mounted) return false;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
        return true;

      case 'swap_message_received':
      case 'swap_offer_received':
      case 'swap_offer_updated':
        final swapOfferId = _parseId(data?['swap_offer_id']);
        if (swapOfferId == null) return false;
        final swapOffer = await apiClient.swapOffer(swapOfferId);
        if (!context.mounted) return false;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SwapOfferThreadScreen(swapOffer: swapOffer),
          ),
        );
        return true;

      case 'group_message_received':
        final groupId = _parseId(data?['group_id']);
        if (groupId == null) return false;
        final group = await apiClient.group(groupId);
        if (!context.mounted) return false;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
        );
        return true;

      case 'user_followed':
        final userId = _parseId(data?['user_id']);
        if (userId == null) return false;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerProfileScreen(userId: userId),
          ),
        );
        return true;

      case 'listing_reviewed':
        final listingId = _parseId(data?['listing_id']);
        if (listingId == null) return false;
        final listing = await apiClient.listing(listingId);
        if (!context.mounted) return false;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listing: listing),
          ),
        );
        return true;

      default:
        return false;
    }
  } catch (_) {
    return false;
  }
}

int? _parseId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
