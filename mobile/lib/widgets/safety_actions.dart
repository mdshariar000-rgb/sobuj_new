import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report.dart';
import '../providers/core_providers.dart';
import '../providers/discovery_providers.dart';
import '../providers/event_providers.dart';
import '../providers/group_providers.dart';
import '../providers/post_providers.dart';
import '../providers/safety_providers.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';

/// Opens the "Report" bottom sheet for [target]/[targetId] — the user-facing
/// half of the report-and-block tooling App Store Guideline 1.2 requires for
/// any app with user-generated content. Reports land in the admin panel's
/// Reports queue.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required int targetId,
}) {
  final messenger = ScaffoldMessenger.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ReportSheet(target: target, targetId: targetId, messenger: messenger),
  );
}

/// Asks for confirmation, then blocks [userId]. Returns true only when the
/// block actually went through, so a caller (e.g. a profile or chat screen)
/// can close itself afterwards.
Future<bool> confirmAndBlockUser(
  BuildContext context, {
  required int userId,
  required String userName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block $userName?'),
      content: const Text(
        "They won't be able to see your posts or contact you, and you won't "
        'see theirs. You can unblock them any time from Profile → Privacy & '
        'Safety → Blocked users.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-block'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  try {
    await container.read(apiClientProvider).blockUser(userId);
    refreshAfterBlockChange(container);
    messenger.showSnackBar(SnackBar(content: Text('Blocked $userName.')));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Unblocks [userId] and refreshes everything that was hiding their content.
Future<void> unblockUser(BuildContext context, int userId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  await container.read(apiClientProvider).unblockUser(userId);
  refreshAfterBlockChange(container);
}

/// Blocking/unblocking changes what almost every list returns (posts, nearby
/// listings, swap inbox, chats, events, comments) — drop their cached data so
/// the next read is fetched fresh, rather than a blocked user's content
/// lingering on screen until a manual pull-to-refresh.
void refreshAfterBlockChange(ProviderContainer container) {
  container
    ..invalidate(blockedUsersProvider)
    ..invalidate(postCommentsProvider)
    ..invalidate(authorPostsProvider)
    ..invalidate(nearbyListingsProvider)
    ..invalidate(savedListingsProvider)
    ..invalidate(mySwapOffersProvider)
    ..invalidate(eventsListProvider)
    ..invalidate(groupPostsProvider)
    ..invalidate(groupMessagesProvider);
}

/// A "⋮" menu offering Report user / Block user for someone else's profile or
/// conversation. Blocking closes the current screen (there's nothing left to
/// show for that user) when [closeAfterBlock] is set.
class UserSafetyMenuButton extends StatelessWidget {
  const UserSafetyMenuButton({
    super.key,
    required this.userId,
    required this.userName,
    this.closeAfterBlock = false,
    this.iconColor,
  });

  final int userId;
  final String userName;
  final bool closeAfterBlock;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('user-safety-menu'),
      icon: Icon(Icons.more_vert, color: iconColor),
      tooltip: 'More options',
      onSelected: (action) async {
        if (action == 'report') {
          showReportSheet(context, target: ReportTarget.user, targetId: userId);
          return;
        }

        final navigator = Navigator.of(context);
        final blocked = await confirmAndBlockUser(
          context,
          userId: userId,
          userName: userName,
        );
        if (blocked && closeAfterBlock && navigator.mounted) navigator.pop();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'report', child: Text('Report user')),
        PopupMenuItem(value: 'block', child: Text('Block $userName')),
      ],
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.target,
    required this.targetId,
    required this.messenger,
  });

  final ReportTarget target;
  final int targetId;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _detailsController = TextEditingController();
  ReportReason? _reason;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .reportContent(
            target: widget.target,
            targetId: widget.targetId,
            reason: reason,
            details: _detailsController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks — our team will review this report.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          key: const Key('report-sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report this ${widget.target.noun}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Why are you reporting it? We'll review it and remove anything "
                'that breaks our rules.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) {
                  if (!_submitting) setState(() => _reason = value);
                },
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        key: Key('report-reason-${reason.wireValue}'),
                        value: reason,
                        title: Text(reason.label),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              TextField(
                key: const Key('report-details'),
                controller: _detailsController,
                maxLength: 500,
                maxLines: 2,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  hintText: 'Add details (optional)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('report-submit'),
                  onPressed: _reason == null || _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
