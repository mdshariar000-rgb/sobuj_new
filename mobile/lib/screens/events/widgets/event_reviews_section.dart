import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/event_review.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/event_providers.dart';
import '../../../services/api_exception.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/safety_actions.dart';
import '../../../widgets/user_avatar.dart';
import '../../../widgets/shimmer.dart';

/// Reviews and comments on an event, newest first, with a box to add one —
/// a star rating, a comment, or both.
class EventReviewsSection extends ConsumerStatefulWidget {
  const EventReviewsSection({super.key, required this.eventId});

  final int eventId;

  @override
  ConsumerState<EventReviewsSection> createState() =>
      _EventReviewsSectionState();
}

class _EventReviewsSectionState extends ConsumerState<EventReviewsSection> {
  final _bodyController = TextEditingController();
  int? _rating;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (_rating == null && body.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(apiClientProvider)
          .reviewEvent(
            widget.eventId,
            rating: _rating,
            body: body.isEmpty ? null : body,
          );
      _bodyController.clear();
      setState(() => _rating = null);
      ref.invalidate(eventReviewsProvider(widget.eventId));
      if (mounted) FocusScope.of(context).unfocus();
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

  Future<void> _delete(EventReview review) async {
    try {
      await ref
          .read(apiClientProvider)
          .deleteEventReview(widget.eventId, review.id);
      ref.invalidate(eventReviewsProvider(widget.eventId));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(eventReviewsProvider(widget.eventId));
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      key: Key('review-star-$star'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                        () => _rating = _rating == star ? null : star,
                      ),
                      icon: Icon(
                        (_rating ?? 0) >= star
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber.shade700,
                      ),
                    ),
                ],
              ),
              TextField(
                key: const Key('review-body-field'),
                controller: _bodyController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Leave a review or ask a question…',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('review-submit'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: const Text('Post'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          loading: () =>
              const ShimmerCardList(count: 2, thumbSize: 36, roundThumb: true),
          error: (error, _) => Text('$error'),
          data: (reviews) => reviews.isEmpty
              ? const Text(
                  'No reviews or comments yet.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final review in reviews)
                      _ReviewTile(
                        review: review,
                        onDelete: review.user?.id == currentUserId
                            ? () => _delete(review)
                            : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, this.onDelete});

  final EventReview review;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = review.user?.name ?? 'A grower';

    return Padding(
      key: Key('event-review-${review.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: name, avatarUrl: review.user?.avatarUrl, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(review.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (review.rating != null)
                  Row(
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Icon(
                          star <= review.rating!
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                    ],
                  ),
                if (review.body != null) ...[
                  const SizedBox(height: 2),
                  Text(review.body!),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          // Someone else's review: report or block its author.
          if (onDelete == null && review.user != null)
            UserSafetyMenuButton(
              userId: review.user!.id,
              userName: review.user!.name,
            ),
        ],
      ),
    );
  }
}
