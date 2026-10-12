import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../models/event_enums.dart';
import '../../providers/event_providers.dart';
import '../../theme/app_colors.dart';
import 'event_detail_screen.dart';
import '../../widgets/shimmer.dart';

const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

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

/// A real month calendar over published events, reached from the Events
/// tab's calendar icon. Days with at least one event get a dot (up to three,
/// so a busy day reads as busier than a quiet one); tapping a day lists
/// that day's events below the grid, soonest first.
class EventsCalendarScreen extends ConsumerStatefulWidget {
  const EventsCalendarScreen({super.key});

  @override
  ConsumerState<EventsCalendarScreen> createState() =>
      _EventsCalendarScreenState();
}

class _EventsCalendarScreenState extends ConsumerState<EventsCalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      // The previously selected day may not exist in the new month (or may
      // just be confusing to keep pointing at) — default to the 1st.
      _selectedDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarMonthEventsProvider(_visibleMonth));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _Header(
            month: _visibleMonth,
            onBack: () => Navigator.of(context).pop(),
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
            onToday: _goToToday,
          ),
          Expanded(
            child: eventsAsync.when(
              loading: () => const ShimmerCardList(count: 4, thumbSize: 48),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$error', textAlign: TextAlign.center),
                ),
              ),
              data: (events) {
                final countByDay = <int, int>{};
                final eventsByDay = <int, List<Event>>{};
                for (final event in events) {
                  final startsAt = event.startsAt;
                  if (startsAt.year != _visibleMonth.year ||
                      startsAt.month != _visibleMonth.month) {
                    continue;
                  }
                  countByDay.update(
                    startsAt.day,
                    (count) => count + 1,
                    ifAbsent: () => 1,
                  );
                  (eventsByDay[startsAt.day] ??= []).add(event);
                }

                final selectedEvents =
                    (eventsByDay[_selectedDay.day] ?? const <Event>[]).toList()
                      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(monthKey(_visibleMonth)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: _MonthGridCard(
                          month: _visibleMonth,
                          selectedDay: _selectedDay,
                          countByDay: countByDay,
                          onSelectDay: (day) =>
                              setState(() => _selectedDay = day),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _DayEventsList(
                          selectedDay: _selectedDay,
                          events: selectedEvents,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onBack;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.forestDark, AppColors.forestPanel],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Events Calendar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onToday,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mint,
                        backgroundColor: AppColors.mint.withValues(alpha: 0.12),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.today_outlined, size: 16),
                      label: const Text('Today'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavButton(
                      key: const Key('calendar-prev-month'),
                      icon: Icons.chevron_left,
                      onTap: onPrev,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        DateFormat('MMMM y').format(month),
                        key: ValueKey(monthKey(month)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    _NavButton(
                      key: const Key('calendar-next-month'),
                      icon: Icons.chevron_right,
                      onTap: onNext,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// The month grid, elevated on its own rounded card so it reads as a
/// distinct panel floating over the screen's background rather than flush
/// content.
class _MonthGridCard extends StatelessWidget {
  const _MonthGridCard({
    required this.month,
    required this.selectedDay,
    required this.countByDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Map<int, int> countByDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: _MonthGrid(
        month: month,
        selectedDay: selectedDay,
        countByDay: countByDay,
        onSelectDay: onSelectDay,
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.countByDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Map<int, int> countByDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // DateTime.weekday: Monday=1..Sunday=7. This grid starts on Sunday, so
    // the leading blank count is 0 for a Sunday-starting month and up to 6
    // otherwise.
    final firstWeekday = DateTime(month.year, month.month).weekday % 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _weekdayLabels.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _weekdayLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: (i == 0 || i == 6)
                          ? AppColors.primary.withValues(alpha: 0.55)
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: firstWeekday + daysInMonth,
          // A fixed row height (not the default square-per-width aspect
          // ratio) — day cells only need to be compact, not as tall as
          // they are wide, which would blow past the available height on
          // a 6-row month.
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 52,
          ),
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox.shrink();

            final day = index - firstWeekday + 1;
            final date = DateTime(month.year, month.month, day);
            final isSelected = DateUtils.isSameDay(date, selectedDay);
            final isToday = DateUtils.isSameDay(date, today);
            final eventCount = countByDay[day] ?? 0;
            final dotCount = eventCount.clamp(0, 3);

            return InkWell(
              key: Key('calendar-day-$day'),
              onTap: () => onSelectDay(date),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: isSelected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.forestPanel],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : isToday
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : null,
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.primary, width: 1.2)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: isToday || isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 14,
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? AppColors.primary
                              : AppColors.textDark,
                        ),
                      ),
                      SizedBox(
                        height: 7,
                        child: dotCount > 0
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < dotCount; i++) ...[
                                    if (i > 0) const SizedBox(width: 2),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DayEventsList extends StatelessWidget {
  const _DayEventsList({required this.selectedDay, required this.events});

  final DateTime selectedDay;
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      // A LayoutBuilder + scroll view rather than a plain Center — the day
      // list area can be quite short (a busy month grid eats most of the
      // screen height), and a fixed-size empty state would overflow it on
      // a small device instead of just scrolling.
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_available_outlined,
                        size: 26,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No events on ${DateFormat('d MMMM').format(selectedDay)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pick another day, or host one yourself from the '
                      'Events tab.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              Text(
                DateFormat('EEEE d MMMM').format(selectedDay),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${events.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final event in events)
          _DayEventTile(
            event: event,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(event: event),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayEventTile extends StatelessWidget {
  const _DayEventTile({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _formatIcon(event.format),
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('h:mm').format(event.startsAt),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(event.startsAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (event.category != null) ...[
                      const SizedBox(height: 6),
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
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
