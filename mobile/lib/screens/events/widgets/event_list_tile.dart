import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/event.dart';
import '../../../models/event_enums.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/image_decode.dart';

/// "Fri 9 Oct · 5:00 pm" — the UK way round, not "Fri, Oct 9". Shown as
/// the host entered it (the app sends event times without converting to
/// UTC), the same as the event page — not shifted to the phone's zone.
String ukEventDate(DateTime when) {
  return '${DateFormat('EEE d MMM').format(when)} · '
      '${DateFormat('h:mm a').format(when).toLowerCase()}';
}

/// A compact event row for the Events lists: cover on the left; date,
/// title, place and who's going on the right — so several fit on a screen.
class EventListTile extends StatelessWidget {
  const EventListTile({super.key, required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final going = event.attendeesCount ?? 0;
    final rsvp = event.myRsvpStatus;
    final isDraft = event.status == EventStatus.draft;

    return Card(
      key: Key('event-tile-${event.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: event.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: event.coverImageUrl!,
                          memCacheWidth: decodeWidthFor(context, 92),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const _CoverFallback(),
                        )
                      : const _CoverFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ukEventDate(event.startsAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          event.format == EventFormat.online
                              ? Icons.videocam_outlined
                              : Icons.place_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.format == EventFormat.online
                                ? 'Online'
                                : (event.location?.isNotEmpty ?? false)
                                ? event.location!
                                : event.format.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isDraft)
                          const _Tag(label: 'Draft', color: AppColors.label)
                        else if (rsvp != null)
                          _Tag(
                            label: "You're ${rsvp.label.toLowerCase()}",
                            color: AppColors.primary,
                            filled: true,
                          ),
                        if (event.isNearYou ?? false)
                          const _Tag(
                            label: 'Near you',
                            color: AppColors.primary,
                          ),
                        if ((event.registrationFee ?? 0) <= 0)
                          const _Tag(label: 'Free', color: AppColors.primary)
                        else
                          _Tag(
                            label: NumberFormat.simpleCurrency(
                              name: 'GBP',
                            ).format(event.registrationFee),
                            color: AppColors.label,
                          ),
                        if (going > 0)
                          _Tag(label: '$going going', color: AppColors.label),
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

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mintLight,
      alignment: Alignment.center,
      child: const Icon(Icons.event, color: AppColors.primary, size: 32),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.filled = false});

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}
