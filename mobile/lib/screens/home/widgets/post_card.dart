import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/post.dart';
import '../../../models/report.dart';
import '../../../providers/core_providers.dart';
import '../../../services/api_exception.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/safety_actions.dart';
import '../../../widgets/user_avatar.dart';
import '../../discovery/seller_profile_screen.dart';
import '../../groups/group_detail_screen.dart';
import '../../../widgets/image_decode.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onLike,
    this.onApprove,
    this.onReject,
    this.showGroupLabel = true,
  });

  final Post post;

  /// Off inside a group's own discussion thread, where "in `group`" on
  /// every post would just repeat the screen's title.
  final bool showGroupLabel;
  final VoidCallback? onTap;

  /// Only passed non-null by a caller that has already confirmed this is
  /// the signed-in user's own post — see PostPolicy::update() on the
  /// backend, which enforces the same rule server-side regardless of what
  /// the app shows.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Null hides the like button entirely (e.g. before auth state is ready)
  /// rather than showing a control that does nothing.
  final VoidCallback? onLike;

  /// Only passed non-null by a caller that has already confirmed both:
  /// this post is genuinely pending (post.isPendingApproval) and the
  /// current user genuinely manages its group — see
  /// GroupDetailScreen's _AllPostsTab. Null hides the moderation row
  /// entirely rather than showing controls that would just 403.
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  /// A truthful stand-in for a role badge: derived from the author's real
  /// growing setup / experience level rather than an invented title like
  /// "Agronomist" — null when neither is set on their profile.
  String? get _roleLabel {
    final setup = post.author?.growingSetup?.label;
    if (setup != null) return '$setup Grower';
    final level = post.author?.experienceLevel?.label;
    if (level != null) return '$level Grower';
    return null;
  }

  void _openAuthorProfile(BuildContext context) =>
      openUserProfile(context, post.author?.id);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authorName = post.author?.name ?? 'Unknown grower';
    final roleLabel = _roleLabel;
    final isVerified = post.author?.isVerified ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => _openAuthorProfile(context),
                    customBorder: const CircleBorder(),
                    child: UserAvatar(
                      name: authorName,
                      avatarUrl: post.author?.avatarUrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAuthorProfile(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  authorName,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            [
                              ?roleLabel,
                              timeago.format(post.createdAt),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (showGroupLabel && post.groupName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: GestureDetector(
                                key: const Key('post-group-label'),
                                behavior: HitTestBehavior.opaque,
                                onTap: post.groupId == null
                                    ? null
                                    : () => openGroupDetail(
                                        context,
                                        post.groupId!,
                                      ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.groups_outlined,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'in ${post.groupName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (post.isPendingApproval || post.isRejected)
                    _ApprovalBadge(isRejected: post.isRejected),
                  if (onEdit == null && onDelete == null && post.author != null)
                    PopupMenuButton<_PostMenuAction>(
                      key: Key('post-safety-menu-${post.id}'),
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Post options',
                      onSelected: (action) {
                        final author = post.author;
                        switch (action) {
                          case _PostMenuAction.report:
                            showReportSheet(
                              context,
                              target: ReportTarget.post,
                              targetId: post.id,
                            );
                          case _PostMenuAction.block:
                            if (author != null) {
                              confirmAndBlockUser(
                                context,
                                userId: author.id,
                                userName: author.name,
                              );
                            }
                          case _PostMenuAction.edit || _PostMenuAction.delete:
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _PostMenuAction.report,
                          child: ListTile(
                            leading: Icon(Icons.flag_outlined),
                            title: Text('Report post'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _PostMenuAction.block,
                          child: ListTile(
                            leading: const Icon(
                              Icons.block,
                              color: AppColors.error,
                            ),
                            title: Text(
                              'Block ${post.author?.name ?? 'user'}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<_PostMenuAction>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Post options',
                      onSelected: (action) => switch (action) {
                        _PostMenuAction.edit => onEdit?.call(),
                        _PostMenuAction.delete => onDelete?.call(),
                        _PostMenuAction.report || _PostMenuAction.block => null,
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: _PostMenuAction.edit,
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit post'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: _PostMenuAction.delete,
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              title: Text(
                                'Delete post',
                                style: TextStyle(color: AppColors.error),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (post.body.isNotEmpty)
                Text(post.body, style: theme.textTheme.bodyMedium),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    width: double.infinity,
                    height: 180,
                    memCacheWidth: decodeWidthFor(context, double.infinity),
                    fit: BoxFit.cover,
                    placeholder: (context, _) =>
                        Container(height: 180, color: AppColors.surfaceMuted),
                    errorWidget: (context, _, _) => Container(
                      height: 180,
                      color: AppColors.surfaceMuted,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  if (onLike != null) ...[
                    _CountButton(
                      icon: (post.likedByMe ?? false)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      iconColor: (post.likedByMe ?? false)
                          ? Colors.redAccent
                          : AppColors.textMuted,
                      label: '${post.likesCount ?? 0}',
                      onTap: onLike,
                    ),
                    const SizedBox(width: 4),
                  ],
                  _CountButton(
                    icon: Icons.mode_comment_outlined,
                    iconColor: AppColors.textMuted,
                    label: (post.commentsCount ?? 0) == 1
                        ? '1 comment'
                        : '${post.commentsCount ?? 0} comments',
                    onTap: onTap,
                  ),
                  if (post.canShare) ...[
                    const SizedBox(width: 4),
                    _CountButton(
                      key: Key('post-share-${post.id}'),
                      icon: Icons.share_outlined,
                      iconColor: AppColors.textMuted,
                      label: 'Share',
                      onTap: () => sharePostOutside(post),
                    ),
                  ],
                ],
              ),
              // Moderation actions get their own row — beside Like/Comment/
              // Share they don't fit on a phone-width card.
              if (onApprove != null || onReject != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onReject != null)
                      TextButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    if (onApprove != null)
                      TextButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A real "Pending Approval"/"Rejected" pill — only ever rendered for a
/// non-admin member's post into a private group (see
/// PostController::store()); every Home Feed post and every public-group
/// post is always approved, so this never shows there.
class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.isRejected});

  final bool isRejected;

  @override
  Widget build(BuildContext context) {
    final color = isRejected ? AppColors.error : Colors.amber.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRejected ? Icons.block : Icons.hourglass_top,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isRejected ? 'Rejected' : 'Pending Approval',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill-free icon+label tap target — deliberately not FilledButton/
/// OutlinedButton, since the app's shared button theme forces those to
/// `Size.fromHeight(52)` (i.e. infinite width), which breaks inline use in a
/// Row (see the Events/Groups cards' `minimumSize: Size.zero` fix for the
/// same bug). A plain InkWell sidesteps it entirely.
class _CountButton extends StatelessWidget {
  const _CountButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PostMenuAction { edit, delete, report, block }

/// Opens a group's detail page from a post's "in `group`" label. The post
/// only carries the group's basics, so the full group (with the viewer's
/// membership and role) is fetched first.
Future<void> openGroupDetail(BuildContext context, int groupId) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final group = await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(apiClientProvider).group(groupId);
    await navigator.push(
      MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Shared "delete post?" confirmation — used by every screen that shows a
/// [PostCard] with a delete action, so the prompt reads the same everywhere.
Future<bool> confirmDeletePost(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete post?'),
      content: const Text("This removes it for everyone and can't be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// "Share" on a post: the phone's own share menu (WhatsApp, Messages, copy
/// …) with who posted it, in which group, and what they said.
void sharePostOutside(Post post) {
  final author = post.author?.name ?? 'A grower';
  final where = post.groupName != null ? ' in ${post.groupName}' : '';
  SharePlus.instance.share(
    ShareParams(text: '$author$where on Shobuj:\n\n${post.body}'),
  );
}
