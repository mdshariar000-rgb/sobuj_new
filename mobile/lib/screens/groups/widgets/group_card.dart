import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/group.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/image_decode.dart';

/// Abbreviates a real member count for display (e.g. 4823 -> "4.8K") — a
/// display transform of real data, not a fabricated number.
String _compactCount(int count) => NumberFormat.compact().format(count);

/// "just now", "5m ago", "3h ago", "2d ago", "3w ago" — short enough to
/// sit beside the member count.
String _shortAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 60) return '${diff.inDays ~/ 7}w ago';
  return DateFormat.yMMMd().format(time);
}

String _members(int count) =>
    '${_compactCount(count)} ${count == 1 ? 'member' : 'members'}';

/// A fixed set of soft tints for groups without a photo, picked from the
/// group's id so each keeps its colour.
const _placeholderTints = [
  Color(0xFFD6F8E3),
  Color(0xFFFDE3CF),
  Color(0xFFD6EAF8),
  Color(0xFFE3D6F8),
  Color(0xFFFFF3C4),
  Color(0xFFF8D6E0),
];

/// One group in the Groups list: picture, name, members and when it was
/// last active, the latest chat line for groups you're in, and Join /
/// Joined / Requested plus the chat button.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onJoin,
    this.onLeave,
    this.onOpenChat,
    this.isBusy = false,
  });

  final Group group;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  /// Called from the "Joined" pill — the screen confirms before leaving.
  final VoidCallback? onLeave;

  final VoidCallback? onOpenChat;
  final bool isBusy;

  String get _meta {
    final parts = [_members(group.membersCount ?? 0)];
    final lastActive = group.lastActivityAt;
    if (lastActive != null) parts.add('Active ${_shortAgo(lastActive)}');
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMember = group.isMember ?? false;
    final isRequested = !isMember && (group.joinRequestPending ?? false);
    final imageUrl = group.avatarUrl ?? group.coverImageUrl;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 56,
                        height: 56,
                        memCacheWidth: decodeWidthFor(context, 56),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color:
                            _placeholderTints[group.id %
                                _placeholderTints.length],
                        alignment: Alignment.center,
                        child: Text(
                          group.name.trim().isEmpty
                              ? '?'
                              : group.name.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestDark,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
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
                        if (group.isPrivate) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isMember && group.lastMessage != null) ...[
                      const SizedBox(height: 4),
                      _ChatPreview(message: group.lastMessage!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isMember) ...[
                if (onOpenChat != null)
                  _ChatButton(
                    key: Key('group-chat-button-${group.id}'),
                    unreadCount: group.unreadCount ?? 0,
                    onPressed: onOpenChat!,
                  ),
                // Already under "My groups", so no "Joined" pill taking up
                // room — leaving sits in this small menu instead.
                if (onLeave != null)
                  isBusy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : PopupMenuButton<void>(
                          key: Key('group-menu-${group.id}'),
                          tooltip: 'More',
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppColors.textMuted,
                          ),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              key: Key('group-leave-${group.id}'),
                              onTap: onLeave,
                              child: const Text('Leave group'),
                            ),
                          ],
                        ),
              ] else if (isRequested)
                const _MembershipPill(
                  label: 'Requested',
                  icon: Icons.schedule,
                  onPressed: null,
                  outlined: true,
                )
              else if (onJoin != null)
                _MembershipPill(
                  key: Key('group-join-${group.id}'),
                  label: 'Join',
                  busy: isBusy,
                  onPressed: onJoin,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipPill extends StatelessWidget {
  const _MembershipPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.outlined = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14),
                const SizedBox(width: 4),
              ],
              Text(label),
            ],
          );
    const padding = EdgeInsets.symmetric(horizontal: 12);
    const size = Size(0, 34);
    return outlined
        ? OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(
              minimumSize: size,
              padding: padding,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: child,
          );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          tooltip: 'Group chat',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.primary,
            minimumSize: const Size(36, 36),
            fixedSize: const Size(36, 36),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: IgnorePointer(child: _UnreadBadge(count: unreadCount)),
          ),
      ],
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
