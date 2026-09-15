import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/post.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/user_avatar.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onDelete,
    this.onLike,
    this.onApprove,
    this.onReject,
  });

  final Post post;
  final VoidCallback? onTap;
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
                  UserAvatar(name: authorName, avatarUrl: post.author?.avatarUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                      ],
                    ),
                  ),
                  if (post.category.toLowerCase() != 'general') ...[
                    _CategoryBadge(category: post.category),
                    const SizedBox(width: 4),
                  ],
                  if (post.isPendingApproval || post.isRejected)
                    _ApprovalBadge(isRejected: post.isRejected),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: 'Delete post',
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(post.body, style: theme.textTheme.bodyMedium),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    width: double.infinity,
                    height: 180,
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
                    label: '${post.commentsCount ?? 0} comments',
                    onTap: onTap,
                  ),
                  if (onApprove != null || onReject != null) ...[
                    const Spacer(),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small colored pill marking a non-General post so it stands out on the
/// unfiltered "Recent" feed too, not just when the matching chip is
/// selected. category is an admin-managed name (see models/post_category.dart),
/// not a fixed set, so the icon is a best-effort substring match — same
/// heuristic as GroupCard's own category icon — rather than an exhaustive
/// switch that would miss any category an admin adds later.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final lower = category.toLowerCase();
    final (icon, color) = switch (lower) {
      _ when lower.contains('disease') || lower.contains('alert') => (
        Icons.warning_amber_rounded,
        Colors.orange,
      ),
      _ when lower.contains('harvest') => (Icons.eco, AppColors.primary),
      _ => (Icons.local_offer_outlined, AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            category,
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
