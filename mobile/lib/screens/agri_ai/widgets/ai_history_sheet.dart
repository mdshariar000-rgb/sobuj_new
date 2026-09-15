import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../providers/ai_providers.dart';
import '../../../services/api_exception.dart';
import '../../../theme/app_colors.dart';

Future<void> showAiHistorySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const AiHistorySheet(),
  );
}

class AiHistorySheet extends ConsumerWidget {
  const AiHistorySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(aiConversationsProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Past conversations',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: conversationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  error is ApiException
                      ? error.message
                      : 'Could not load history.',
                ),
              ),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return const Center(
                    child: Text(
                      'No conversations yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceMuted,
                        child: Icon(
                          Icons.spa_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        conversation.title?.isNotEmpty ?? false
                            ? conversation.title!
                            : 'Conversation',
                      ),
                      subtitle: Text(timeago.format(conversation.updatedAt)),
                      onTap: () {
                        ref
                            .read(aiChatProvider.notifier)
                            .openConversation(conversation.id);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
