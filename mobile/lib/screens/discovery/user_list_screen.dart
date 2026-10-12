import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import 'seller_profile_screen.dart';
import '../../widgets/shimmer.dart';

/// A simple "Followers" / "Following" list — reached by tapping either count
/// on a profile. Reuses openUserProfile so tapping a row goes to that
/// grower's own profile, same destination as every other avatar in the app.
class UserListScreen extends ConsumerWidget {
  const UserListScreen({
    super.key,
    required this.title,
    required this.provider,
    required this.emptyMessage,
  });

  final String title;
  final AutoDisposeFutureProvider<List<AppUser>> provider;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: usersAsync.when(
        loading: () => const ShimmerCardList(thumbSize: 44, roundThumb: true),
        error: (error, _) => Center(child: Text('$error')),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(provider),
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: UserAvatar(
                    name: user.name,
                    avatarUrl: user.avatarUrl,
                    radius: 20,
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: user.username != null
                      ? Text('@${user.username}')
                      : null,
                  onTap: () => openUserProfile(context, user.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
