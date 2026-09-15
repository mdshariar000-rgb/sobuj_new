import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/group.dart';
import '../../providers/group_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';

/// The group admin/creator's real moderation queue for pending requests to
/// join a private group — see GET/PATCH /groups/{id}/join-requests on the
/// backend. Only reachable from GroupDetailScreen's admin-only banner.
class GroupJoinRequestsScreen extends ConsumerWidget {
  const GroupJoinRequestsScreen({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(groupJoinRequestsProvider(group.id));

    Future<void> decide(int requestId, {required bool approve}) async {
      final notifier = ref.read(groupJoinRequestsProvider(group.id).notifier);
      try {
        if (approve) {
          await notifier.approve(requestId);
        } else {
          await notifier.reject(requestId);
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not update that request. Try again.'),
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Join Requests'),
        backgroundColor: AppColors.forestDark,
        foregroundColor: Colors.white,
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text(
                'No pending requests.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return ListTile(
                leading: UserAvatar(
                  name: request.user.name,
                  avatarUrl: request.user.avatarUrl,
                ),
                title: Text(request.user.name),
                subtitle: request.requestedAt != null
                    ? Text('Requested ${timeago.format(request.requestedAt!)}')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('join-request-reject-${request.id}'),
                      onPressed: () => decide(request.id, approve: false),
                      icon: const Icon(Icons.close),
                      color: AppColors.error,
                      tooltip: 'Reject',
                    ),
                    IconButton(
                      key: Key('join-request-approve-${request.id}'),
                      onPressed: () => decide(request.id, approve: true),
                      icon: const Icon(Icons.check),
                      color: AppColors.primary,
                      tooltip: 'Approve',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
