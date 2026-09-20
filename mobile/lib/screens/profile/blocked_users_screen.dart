import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/safety_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';

/// Everyone the signed-in user has blocked, each with an Unblock button.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Blocked users'),
        backgroundColor: AppColors.forestDark,
        foregroundColor: Colors.white,
      ),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ApiException
                      ? error.message
                      : "Couldn't load blocked users.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(blockedUsersProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "You haven't blocked anyone.",
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];

              return ListTile(
                key: Key('blocked-user-${user.id}'),
                leading: UserAvatar(name: user.name, avatarUrl: user.avatarUrl),
                title: Text(user.name),
                subtitle: user.username != null ? Text('@${user.username}') : null,
                trailing: TextButton(
                  key: Key('unblock-${user.id}'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await unblockUser(context, user.id);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Unblocked ${user.name}.')),
                      );
                    } on ApiException catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
