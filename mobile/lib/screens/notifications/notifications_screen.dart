import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/app_notification.dart';
import '../../providers/core_providers.dart';
import '../../providers/notification_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/seller_profile_screen.dart';
import 'notification_deep_link.dart';
import '../../widgets/shimmer.dart';

/// The real notification inbox — reached from the bell icon on the Home/
/// Events/Groups tabs. Post liked/commented/replied-to, and swap-offer/
/// group messages, newest first — see AppNotificationResource on the
/// backend.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsListProvider.notifier).loadMore();
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    ref.read(notificationsListProvider.notifier).markRead(notification.id);

    final navigated = await openNotificationDeepLink(
      context,
      ref.read(apiClientProvider),
      notification,
    );
    if (!navigated && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.forestDark,
        foregroundColor: Colors.white,
        // The theme's title style carries its own dark color, which beats
        // foregroundColor — set white explicitly for this dark bar.
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationsListProvider.notifier).markAllRead(),
            style: TextButton.styleFrom(foregroundColor: AppColors.mint),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const ShimmerCardList(thumbSize: 44, roundThumb: true),
        error: (error, _) => Center(child: Text('$error')),
        data: (state) {
          final notifications = state.notifications;
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "You're all caught up",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Likes, comments, and messages will show up here.',
                      style: TextStyle(color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationsListProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: notifications.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _openNotification(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actorName = notification.actor?.name ?? 'Shobuj';

    // A Material (not a colored Container) so the unread tint doesn't hide
    // the ListTile's tap ripple.
    return Material(
      color: notification.isUnread
          ? AppColors.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: InkWell(
          onTap: () => openUserProfile(context, notification.actor?.id),
          customBorder: const CircleBorder(),
          child: UserAvatar(
            name: actorName,
            avatarUrl: notification.actor?.avatarUrl,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isUnread
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${notification.body}\n${timeago.format(notification.createdAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: notification.isUnread
            ? const Icon(Icons.circle, size: 10, color: AppColors.primary)
            : null,
      ),
    );
  }
}
