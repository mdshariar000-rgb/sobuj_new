import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/event_enums.dart';
import '../../models/report.dart';
import '../../providers/auth_providers.dart';
import '../../providers/event_providers.dart';
import '../../providers/core_providers.dart';
import '../../services/api_exception.dart';
import '../groups/group_chat_screen.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/seller_profile_screen.dart';
import 'create_event_screen.dart';
import 'widgets/event_reviews_section.dart';
import '../../widgets/image_decode.dart';

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

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isRsvping = false;
  bool _isTogglingSaved = false;
  bool _isOpeningChat = false;

  Future<void> _onChatTapped(Event event, bool canChat) async {
    if (!canChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RSVP as going to join this event’s chat.'),
        ),
      );
      return;
    }
    setState(() => _isOpeningChat = true);
    try {
      await openEventChat(context, ref, event);
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  Future<void> _rsvp(EventAttendeeStatus status) async {
    setState(() => _isRsvping = true);
    try {
      await ref.read(eventDetailProvider(widget.event).notifier).rsvp(status);
      if (mounted && status == EventAttendeeStatus.going) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spot reserved! You’re on the list.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRsvping = false);
    }
  }

  Future<void> _cancelRsvp() async {
    setState(() => _isRsvping = true);
    try {
      await ref.read(eventDetailProvider(widget.event).notifier).cancelRsvp();
    } finally {
      if (mounted) setState(() => _isRsvping = false);
    }
  }

  Future<void> _toggleSaved() async {
    setState(() => _isTogglingSaved = true);
    try {
      await ref.read(eventDetailProvider(widget.event).notifier).toggleSaved();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update saved events.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingSaved = false);
    }
  }

  /// Opens the event in the editor, then reloads it so the changes show.
  Future<void> _edit(Event event) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CreateEventScreen(event: event)));
    if (!mounted) return;
    ref.read(eventDetailProvider(widget.event).notifier).refresh();
    ref.invalidate(hostingEventsProvider);
  }

  void _share(Event event) {
    final dateFormat = DateFormat('EEE d MMM · h:mm a');
    final lines = [
      event.title,
      dateFormat.format(event.startsAt),
      if (event.location != null) event.location!,
    ];
    SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  /// Opens Google Calendar's "add event" web template pre-filled with the
  /// real event details — no native calendar plugin needed, so it works the
  /// same on every device with a browser or the Calendar app installed.
  Future<void> _addToCalendar(Event event) async {
    final start = event.startsAt.toUtc();
    final end = (event.endsAt ?? event.startsAt.add(const Duration(hours: 2)))
        .toUtc();
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': event.title,
      'dates': '${_calendarUtc(start)}/${_calendarUtc(end)}',
      if (event.description != null) 'details': event.description,
      if (event.location != null) 'location': event.location,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _calendarUtc(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  Future<void> _getDirections(String location) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': location,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showAllAttendees(Event event) {
    final preview = event.attendeesPreview ?? const <AppUser>[];
    final totalCount = event.attendeesCount ?? preview.length;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Growers Attending · $totalCount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: preview.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) =>
                        _AttendeeTile(user: preview[index]),
                  ),
                ),
                if (totalCount > preview.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+ ${totalCount - preview.length} more registered',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventAsync = ref.watch(eventDetailProvider(widget.event));
    final event = eventAsync.valueOrNull ?? widget.event;
    final dateFormat = DateFormat('EEEE d MMMM y · h:mm a');
    final isSaved = event.isSaved ?? false;
    final capacity = event.capacity;
    final attendeesCount = event.attendeesCount ?? 0;
    final spotsRemaining = capacity != null ? capacity - attendeesCount : null;
    final hasChat = event.id > 0 && event.status == EventStatus.published;
    final isHost =
        event.host != null &&
        event.host!.id == ref.watch(authControllerProvider).valueOrNull?.id;
    final canChat = event.myRsvpStatus == EventAttendeeStatus.going || isHost;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroSection(event: event, spotsRemaining: spotsRemaining),
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.group != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.groups_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              event.group!.name.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        event.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (event.host != null) ...[
                        _HostCard(host: event.host!),
                        const SizedBox(height: 20),
                      ],
                      _ScheduleCard(
                        event: event,
                        dateFormat: dateFormat,
                        onGetDirections: event.location != null
                            ? () => _getDirections(event.location!)
                            : null,
                      ),
                      if (hasChat) ...[
                        const SizedBox(height: 16),
                        _EventChatCard(event: event, canChat: canChat),
                      ],
                      if (event.myRsvpStatus == null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isRsvping
                                ? null
                                : () => _rsvp(EventAttendeeStatus.interested),
                            child: const Text(
                              'Just interested, not going yet?',
                            ),
                          ),
                        ),
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionHeading(
                          icon: Icons.menu_book_outlined,
                          title: 'About This Event',
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            event.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      if ((event.attendeesPreview ?? const []).isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionHeading(
                          icon: Icons.diversity_3_outlined,
                          title: 'Growers Attending',
                        ),
                        const SizedBox(height: 10),
                        _AttendeesCard(
                          event: event,
                          onViewAll: () => _showAllAttendees(event),
                        ),
                      ],
                      // Not on the create screen's preview (id -1) or a
                      // draft — only published events take reviews.
                      if (event.id > 0 &&
                          event.status == EventStatus.published) ...[
                        const SizedBox(height: 24),
                        const _SectionHeading(
                          icon: Icons.rate_review_outlined,
                          title: 'Reviews & Comments',
                        ),
                        const SizedBox(height: 10),
                        EventReviewsSection(eventId: event.id),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 10,
            child: _HeroIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 10,
            child: Row(
              children: [
                if (isHost && event.id > 0) ...[
                  _HeroIconButton(
                    key: const Key('event-edit-button'),
                    icon: Icons.edit_outlined,
                    onTap: () => _edit(event),
                  ),
                  const SizedBox(width: 10),
                ],
                _HeroIconButton(
                  icon: Icons.share_outlined,
                  onTap: () => _share(event),
                ),
                const SizedBox(width: 10),
                _HeroIconButton(
                  key: const Key('event-detail-save-button'),
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  iconColor: isSaved ? AppColors.mint : Colors.white,
                  onTap: _isTogglingSaved ? null : _toggleSaved,
                ),
                if (event.host != null &&
                    event.host!.id !=
                        ref.watch(authControllerProvider).valueOrNull?.id) ...[
                  const SizedBox(width: 10),
                  _HeroIconButton(
                    key: const Key('event-report-button'),
                    icon: Icons.flag_outlined,
                    onTap: () => showReportSheet(
                      context,
                      target: ReportTarget.event,
                      targetId: event.id,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomActionBar(
              event: event,
              isBusy: _isRsvping,
              onAddToCalendar: () => _addToCalendar(event),
              onRsvpGoing: () => _rsvp(EventAttendeeStatus.going),
              onCancelRsvp: _cancelRsvp,
              onChat: hasChat ? () => _onChatTapped(event, canChat) : null,
              isOpeningChat: _isOpeningChat,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.event, required this.spotsRemaining});

  final Event event;
  final int? spotsRemaining;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (event.coverImageUrl != null)
            CachedNetworkImage(
              imageUrl: event.coverImageUrl!,
              memCacheWidth: decodeWidthFor(context, double.infinity),
              fit: BoxFit.cover,
            )
          else
            Container(
              color: AppColors.forestPanel,
              alignment: Alignment.center,
              child: Icon(
                _formatIcon(event.format),
                size: 56,
                color: AppColors.mint,
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 36,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill(
                  icon: _formatIcon(event.format),
                  label: event.format.label.toUpperCase(),
                  dark: true,
                ),
                if (event.category != null)
                  _HeroPill(
                    icon: Icons.sell_outlined,
                    label: event.category!.toUpperCase(),
                  ),
                // Every event in this app is free to RSVP for — there's no
                // paid-ticketing feature — so this is a real, always-true
                // fact rather than a fabricated price.
                const _HeroPill(icon: Icons.eco, label: 'Free Admission'),
                if (spotsRemaining != null)
                  _HeroPill(
                    icon: Icons.event_seat_outlined,
                    label: spotsRemaining! > 0
                        ? '$spotsRemaining Spots Remaining'
                        : 'Fully Booked',
                    dark: spotsRemaining! <= 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label, this.dark = false});

  final IconData icon;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.forestDark.withValues(alpha: 0.8)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dark ? Border.all(color: AppColors.mint, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: dark ? AppColors.mint : AppColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.forestDark.withValues(alpha: 0.7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 19, color: iconColor),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ],
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.host});

  final AppUser host;

  @override
  Widget build(BuildContext context) {
    final isVerified = host.isVerified ?? false;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SellerProfileScreen(userId: host.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  name: host.name,
                  avatarUrl: host.avatarUrl,
                  radius: 24,
                ),
                if (isVerified)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
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
                          host.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.buttonMuted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Verified Host',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (host.bio != null && host.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      host.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.event,
    required this.dateFormat,
    required this.onGetDirections,
  });

  final Event event;
  final DateFormat dateFormat;
  final VoidCallback? onGetDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [
                    dateFormat.format(event.startsAt),
                    if (event.endsAt != null)
                      DateFormat('h:mm a').format(event.endsAt!),
                  ].join(' – '),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (event.proposedDates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Also proposed:',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  for (final date in event.proposedDates)
                    Text(
                      dateFormat.format(date.toLocal()),
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (event.registrationFee ?? 0) > 0
                      ? 'Registration fee: '
                            '${NumberFormat.simpleCurrency(name: 'GBP').format(event.registrationFee)}'
                            ' · paid at the event'
                      : 'Free event',
                  key: const Key('event-fee-label'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (event.location != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.location!,
                    style: const TextStyle(height: 1.3),
                  ),
                ),
                if (onGetDirections != null)
                  TextButton.icon(
                    onPressed: onGetDirections,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.directions_outlined, size: 16),
                    label: const Text('Directions'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendeesCard extends StatelessWidget {
  const _AttendeesCard({required this.event, required this.onViewAll});

  final Event event;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final preview = event.attendeesPreview ?? const <AppUser>[];
    final shown = preview.take(5).toList();
    final remaining = (event.attendeesCount ?? preview.length) - shown.length;
    final stackedCount = shown.length + (remaining > 0 ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 36,
            width: stackedCount == 0 ? 0 : (stackedCount - 1) * 24.0 + 36,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * 24.0,
                    child: _AttendeeAvatar(user: shown[i]),
                  ),
                if (remaining > 0)
                  Positioned(
                    left: shown.length * 24.0,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '+$remaining',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forestDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(onPressed: onViewAll, child: const Text('View All')),
        ],
      ),
    );
  }
}

class _AttendeeAvatar extends StatelessWidget {
  const _AttendeeAvatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openUserProfile(context, user.id),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: UserAvatar(
          name: user.name,
          avatarUrl: user.avatarUrl,
          radius: 18,
        ),
      ),
    );
  }
}

class _AttendeeTile extends StatelessWidget {
  const _AttendeeTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _AttendeeAvatar(user: user),
      title: Text(user.name),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerProfileScreen(userId: user.id),
          ),
        );
      },
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.event,
    required this.isBusy,
    required this.onAddToCalendar,
    required this.onRsvpGoing,
    required this.onCancelRsvp,
    this.onChat,
    this.isOpeningChat = false,
  });

  final Event event;
  final bool isBusy;
  final VoidCallback onAddToCalendar;
  final VoidCallback onRsvpGoing;
  final VoidCallback onCancelRsvp;

  /// Opens this event's own chat; null where the event has none (drafts,
  /// the create screen's preview).
  final VoidCallback? onChat;
  final bool isOpeningChat;

  @override
  Widget build(BuildContext context) {
    final myStatus = event.myRsvpStatus;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ticket Price',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                Text(
                  myStatus != null
                      ? "You're ${myStatus.label}"
                      : (event.registrationFee ?? 0) > 0
                      ? NumberFormat.simpleCurrency(
                          name: 'GBP',
                        ).format(event.registrationFee)
                      : 'Free Admission',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onAddToCalendar,
            icon: const Icon(Icons.event_available_outlined),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.buttonMuted,
              foregroundColor: AppColors.textDark,
            ),
          ),
          if (onChat != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('event-bottom-chat-button'),
              tooltip: 'Event chat',
              onPressed: isOpeningChat ? null : onChat,
              icon: const Icon(Icons.forum_outlined),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.mint.withValues(alpha: 0.35),
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(width: 8),
          if (myStatus == null)
            FilledButton(
              onPressed: isBusy ? null : onRsvpGoing,
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              child: const Text('RSVP / Register'),
            )
          else
            TextButton(
              onPressed: isBusy ? null : onCancelRsvp,
              child: const Text('Cancel RSVP'),
            ),
        ],
      ),
    );
  }
}

/// Opens [event]'s own chat (created server-side on first open). Shared by
/// the bottom bar's chat button and the Event chat card.
Future<void> openEventChat(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  try {
    final group = await ref.read(apiClientProvider).eventChat(event.id);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// The event's conversation: open it if you're the host or going;
/// otherwise a note that going is what gets you in.
class _EventChatCard extends ConsumerStatefulWidget {
  const _EventChatCard({required this.event, required this.canChat});

  final Event event;
  final bool canChat;

  @override
  ConsumerState<_EventChatCard> createState() => _EventChatCardState();
}

class _EventChatCardState extends ConsumerState<_EventChatCard> {
  bool _isOpening = false;

  Future<void> _open() async {
    setState(() => _isOpening = true);
    try {
      await openEventChat(context, ref, widget.event);
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event chat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.canChat
                      ? 'Talk with everyone going.'
                      : 'RSVP as going to join the conversation.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (widget.canChat)
            FilledButton(
              key: const Key('open-event-chat'),
              onPressed: _isOpening ? null : _open,
              // The theme's full-width minimumSize can't lay out in a Row.
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: const Text('Open'),
            ),
        ],
      ),
    );
  }
}
