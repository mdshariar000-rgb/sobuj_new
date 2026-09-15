import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/event.dart';
import '../../../models/event_enums.dart';
import '../../../providers/event_providers.dart';
import '../../../theme/app_colors.dart';

IconData _formatIcon(EventFormat format) {
  switch (format) {
    case EventFormat.inPerson:
      return Icons.grass;
    case EventFormat.online:
      return Icons.videocam_outlined;
    case EventFormat.hybrid:
      return Icons.sync_alt;
  }
}

class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final Event event;
  final VoidCallback? onTap;

  /// The reference design's "By {group}" line — only shown when the event is
  /// actually attached to a real group (no fabricated affiliations).
  String? get _hostLine {
    final group = event.group;
    if (group != null) return 'By ${group.name}';
    final host = event.host;
    if (host != null) return 'Hosted by ${host.name}';
    return null;
  }

  void _share() {
    final dateFormat = DateFormat('EEE, MMM d · h:mm a');
    final lines = [
      event.title,
      dateFormat.format(event.startsAt),
      if (event.location != null) event.location!,
    ];
    SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _toggleSaved(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(eventsListProvider.notifier).toggleSaved(event);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update saved events.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d · h:mm a');
    final hostLine = _hostLine;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (event.coverImageUrl != null)
                  CachedNetworkImage(
                    imageUrl: event.coverImageUrl!,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 90,
                    color: AppColors.surfaceMuted,
                    alignment: Alignment.center,
                    child: Icon(
                      _formatIcon(event.format),
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _Pill(
                    icon: _formatIcon(event.format),
                    label: event.format.label,
                    dark: true,
                  ),
                ),
                // Every event in this app is free — there's no paid-events
                // feature — so this pill is a real, always-true fact rather
                // than a fabricated price.
                const Positioned(
                  right: 10,
                  top: 10,
                  child: _Pill(icon: Icons.eco, label: 'Free', dark: false),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateFormat.format(event.startsAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _toggleSaved(context, ref),
                        icon: Icon(
                          (event.isSaved ?? false)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 18,
                          color: (event.isSaved ?? false)
                              ? AppColors.primary
                              : null,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _share,
                        icon: const Icon(Icons.share_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.category != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mint.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.category!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hostLine != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hostLine,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: event.myRsvpStatus != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "You're ${event.myRsvpStatus!.label}",
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ]
                              )
                            : event.attendeesCount != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people_alt_outlined,
                                    size: 15,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${event.attendeesCount} going',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          // Override the app-wide full-width button theme
                          // (Size.fromHeight => infinite width) — this
                          // button sits inline in a Row next to other
                          // content, not stretched across a form.
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          event.myRsvpStatus != null
                              ? 'View Details'
                              : 'RSVP / Register',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.dark});

  final IconData icon;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.forestDark.withValues(alpha: 0.75)
            : AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: dark ? Colors.white : AppColors.forestDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : AppColors.forestDark,
            ),
          ),
        ],
      ),
    );
  }
}
