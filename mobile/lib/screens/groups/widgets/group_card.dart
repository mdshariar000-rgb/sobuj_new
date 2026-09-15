import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/group.dart';
import '../../../theme/app_colors.dart';

/// A small decorative icon keyed to a handful of category strings that show
/// up in the demo data — purely cosmetic pairing for a real, existing
/// category value (never invents a category that isn't there). Anything
/// that doesn't match falls back to a generic groups icon.
IconData _categoryIcon(String? category) {
  final normalized = category?.toLowerCase() ?? '';
  if (normalized.contains('hydro')) return Icons.science_outlined;
  if (normalized.contains('soil') || normalized.contains('compost')) {
    return Icons.eco_outlined;
  }
  if (normalized.contains('orchid') || normalized.contains('flor')) {
    return Icons.local_florist_outlined;
  }
  if (normalized.contains('home') || normalized.contains('permacul')) {
    return Icons.cottage_outlined;
  }
  if (normalized.contains('fruit') || normalized.contains('orchard')) {
    return Icons.park_outlined;
  }
  return Icons.groups_outlined;
}

/// Abbreviates a real member count for display (e.g. 4823 -> "4.8K") — a
/// display transform of real data, not a fabricated number.
String _compactCount(int count) => NumberFormat.compact().format(count);

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onJoin,
    this.onLeave,
    this.isBusy = false,
  });

  final Group group;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMember = group.isMember ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (group.avatarUrl ?? group.coverImageUrl) != null
                    ? CachedNetworkImage(
                        imageUrl: (group.avatarUrl ?? group.coverImageUrl)!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.surfaceMuted,
                        child: Icon(
                          _categoryIcon(group.category),
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.category != null) ...[
                      Row(
                        children: [
                          Icon(
                            _categoryIcon(group.category),
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              group.category!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.isVerified ?? false) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ],
                        if ((group.unreadCount ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          _UnreadBadge(count: group.unreadCount!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.postsTodayCount != null
                          ? '${_compactCount(group.membersCount ?? 0)} members • ${group.postsTodayCount} posts today'
                          : '${_compactCount(group.membersCount ?? 0)} members',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // A conversation-list-style preview of the group chat's
                    // real most-recent message — only shown for a group this
                    // user has joined and that actually has chat history.
                    if (isMember && group.lastMessage != null) ...[
                      const SizedBox(height: 6),
                      _ChatPreview(message: group.lastMessage!),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (onJoin != null || onLeave != null)
                          SizedBox(
                            height: 34,
                            child: isMember
                                ? FilledButton.tonalIcon(
                                    onPressed: isBusy ? null : onLeave,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.mint,
                                      foregroundColor: AppColors.primary,
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                    ),
                                    icon: isBusy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.check, size: 16),
                                    label: const Text('Joined'),
                                  )
                                : FilledButton(
                                    onPressed: isBusy ? null : onJoin,
                                    style: FilledButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: isBusy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Join'),
                                  ),
                          ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A WhatsApp/Messenger-style one-line preview of a group chat's most
/// recent message — sender name (when it's not this user's own message)
/// plus body/photo indicator, bolded while unread.
class _ChatPreview extends StatelessWidget {
  const _ChatPreview({required this.message});

  final GroupLastMessage message;

  String get _text {
    final body = message.body;
    final content = (body != null && body.isNotEmpty)
        ? body
        : (message.hasImage ? '📷 Photo' : '');
    return message.senderName != null
        ? '${message.senderName}: $content'
        : content;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textDark, fontSize: 13),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          timeago.format(message.createdAt),
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
