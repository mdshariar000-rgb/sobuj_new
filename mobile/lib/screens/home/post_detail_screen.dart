import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../models/report.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/group_providers.dart';
import '../../providers/post_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/seller_profile_screen.dart';
import 'widgets/edit_post_sheet.dart';
import 'widgets/post_card.dart';
import '../../widgets/shimmer.dart';

/// A single post plus its comment thread — reached by tapping a [PostCard]
/// in the Home Feed (and, in a later phase, a group's discussion thread,
/// since both share the same Post/Comment backend model).
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;

  /// A local, live copy of the post — likes/comments update it immediately,
  /// and both changes are also pushed into whichever list provider (Home
  /// Feed or a group's discussion) the post came from, so going back shows
  /// the same up-to-date counts without a manual refresh.
  late Post _post = widget.post;

  /// The specific comment (top-level or a reply) the next submission will
  /// reply to — null means a plain top-level comment.
  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    // Re-anchor to the bottom once the keyboard finishes opening — a plain
    // ListView doesn't automatically follow the shrinking viewport, so
    // without this the comment you're replying to (or just wrote) ends up
    // hidden behind the keyboard the moment you tap in to type.
    _commentFocusNode.addListener(() {
      if (_commentFocusNode.hasFocus) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Keeps the comment count on the group's post list in step.
  void _updateCommentsCountInOrigin(int commentsCount) {
    final groupId = _post.groupId;
    if (groupId == null) return;
    ref
        .read(groupPostsProvider(groupId).notifier)
        .updateCommentsCount(_post.id, commentsCount);
  }

  void _startReply(Comment comment) {
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(postCommentsProvider(widget.post.id).notifier)
          .addComment(body, replyToCommentId: _replyingTo?.id);
      _commentController.clear();
      final commentsCount =
          ref.read(postCommentsProvider(widget.post.id)).valueOrNull?.length ??
          (_post.commentsCount ?? 0) + 1;
      setState(() {
        _post = _post.copyWith(commentsCount: commentsCount);
        _replyingTo = null;
      });
      _updateCommentsCountInOrigin(commentsCount);
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    await ref
        .read(postCommentsProvider(widget.post.id).notifier)
        .deleteComment(commentId);
    final commentsCount =
        ref.read(postCommentsProvider(widget.post.id)).valueOrNull?.length ?? 0;
    setState(() => _post = _post.copyWith(commentsCount: commentsCount));
    _updateCommentsCountInOrigin(commentsCount);
  }

  void _editPost() {
    showEditPostSheet(
      context,
      post: _post,
      onSubmit: (ref, body, image, removeImage) async {
        final groupId = _post.groupId;
        final updated = groupId == null
            ? await ref
                  .read(apiClientProvider)
                  .updatePost(
                    _post.id,
                    body: body,
                    image: image,
                    removeImage: removeImage,
                  )
            : await ref
                  .read(groupPostsProvider(groupId).notifier)
                  .updatePost(
                    _post.id,
                    body: body,
                    image: image,
                    removeImage: removeImage,
                  );
        if (mounted) setState(() => _post = updated);
      },
    );
  }

  Future<void> _deletePost() async {
    if (!await confirmDeletePost(context) || !mounted) return;

    final groupId = _post.groupId;
    if (groupId == null) {
      await ref.read(apiClientProvider).deletePost(_post.id);
    } else {
      await ref.read(groupPostsProvider(groupId).notifier).deletePost(_post.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleLike() async {
    final postBeforeToggle = _post;
    final wasLiked = _post.likedByMe ?? false;
    setState(
      () => _post = _post.copyWith(
        likedByMe: !wasLiked,
        likesCount: (_post.likesCount ?? 0) + (wasLiked ? -1 : 1),
      ),
    );

    try {
      final groupId = _post.groupId;
      if (groupId == null) {
        final api = ref.read(apiClientProvider);
        wasLiked
            ? await api.unlikePost(_post.id)
            : await api.likePost(_post.id);
      } else {
        await ref
            .read(groupPostsProvider(groupId).notifier)
            .toggleLike(postBeforeToggle);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _post = postBeforeToggle);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.post.id));
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                PostCard(
                  post: _post,
                  onEdit: _post.author?.id == currentUserId ? _editPost : null,
                  onDelete: _post.author?.id == currentUserId
                      ? _deletePost
                      : null,
                  onLike: _toggleLike,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Comments',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                commentsAsync.when(
                  loading: () => const ShimmerCardList(
                    count: 3,
                    thumbSize: 36,
                    roundThumb: true,
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error is ApiException
                          ? error.message
                          : 'Could not load comments.',
                    ),
                  ),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No comments yet — be the first to reply.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    final topLevel = comments
                        .where((comment) => !comment.isReply)
                        .toList();
                    final repliesByParent = <int, List<Comment>>{};
                    for (final comment in comments.where(
                      (comment) => comment.isReply,
                    )) {
                      (repliesByParent[comment.parentId!] ??= []).add(comment);
                    }

                    return Column(
                      children: [
                        for (final comment in topLevel) ...[
                          _CommentTile(
                            comment: comment,
                            isOwn: comment.author?.id == currentUserId,
                            canDelete:
                                comment.author?.id == currentUserId ||
                                _post.author?.id == currentUserId,
                            onDelete: () => _deleteComment(comment.id),
                            onReply: () => _startReply(comment),
                          ),
                          for (final reply
                              in repliesByParent[comment.id] ?? const [])
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: _CommentTile(
                                comment: reply,
                                isOwn: reply.author?.id == currentUserId,
                                canDelete:
                                    reply.author?.id == currentUserId ||
                                    _post.author?.id == currentUserId,
                                onDelete: () => _deleteComment(reply.id),
                                onReply: () => _startReply(reply),
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to '
                              '${_replyingTo!.author?.name ?? 'Unknown grower'}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _cancelReply,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Write a reply...'
                                : 'Write a comment...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isSubmitting ? null : _submitComment,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isOwn,
    required this.canDelete,
    required this.onDelete,
    required this.onReply,
  });

  final Comment comment;

  /// Whether the signed-in user wrote this comment — own comments get a plain
  /// delete button; everyone else's get a Report/Block menu instead.
  final bool isOwn;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final authorName = comment.author?.name ?? 'Unknown grower';

    return ListTile(
      leading: GestureDetector(
        onTap: () => openUserProfile(context, comment.author?.id),
        child: UserAvatar(
          name: authorName,
          avatarUrl: comment.author?.avatarUrl,
          radius: comment.isReply ? 14 : 16,
        ),
      ),
      title: GestureDetector(
        onTap: () => openUserProfile(context, comment.author?.id),
        child: Text(
          authorName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The replied-to name is bold and inline with the body — the same
          // pattern Facebook/Instagram use for a reply that's addressing a
          // specific person within the thread.
          Text.rich(
            TextSpan(
              children: [
                if (comment.replyingToName != null)
                  TextSpan(
                    text: '${comment.replyingToName} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                TextSpan(text: comment.body),
              ],
              style: DefaultTextStyle.of(context).style,
            ),
          ),
          const SizedBox(height: 4),
          // A Wrap rather than a Row: the trailing ⋮ menu narrows the tile, and
          // on a small screen the timestamp + Reply must flow rather than clip.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                timeago.format(comment.createdAt),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              InkWell(
                onTap: onReply,
                child: const Text(
                  'Reply',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: _buildTrailing(context),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    if (isOwn) {
      return canDelete
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            )
          : null;
    }

    final author = comment.author;

    return PopupMenuButton<String>(
      key: Key('comment-menu-${comment.id}'),
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: 'Comment options',
      onSelected: (action) {
        switch (action) {
          case 'delete':
            onDelete();
          case 'report':
            showReportSheet(
              context,
              target: ReportTarget.comment,
              targetId: comment.id,
            );
          case 'block':
            if (author != null) {
              confirmAndBlockUser(
                context,
                userId: author.id,
                userName: author.name,
              );
            }
        }
      },
      itemBuilder: (context) => [
        if (canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Delete comment')),
        const PopupMenuItem(value: 'report', child: Text('Report comment')),
        if (author != null)
          PopupMenuItem(value: 'block', child: Text('Block ${author.name}')),
      ],
    );
  }
}
