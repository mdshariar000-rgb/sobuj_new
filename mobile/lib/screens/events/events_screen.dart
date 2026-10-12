import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/event.dart';
import '../../models/event_category.dart';
import '../../providers/auth_providers.dart';
import '../../providers/event_providers.dart';
import '../../theme/app_colors.dart';
import '../discovery/widgets/discovery_error_view.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../shell/widgets/coming_soon_view.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import 'events_calendar_screen.dart';
import 'widgets/event_list_tile.dart';
import 'widgets/events_hero_header.dart';
import '../../widgets/shimmer.dart';

/// The Events tab: "Upcoming" (search, categories, events near you first)
/// and "My events" (going, hosting, saved, drafts). The + button hosts a
/// new event.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _host() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const CreateEventScreen()));

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        key: const Key('host-event-button'),
        heroTag: 'events-fab',
        onPressed: _host,
        tooltip: 'Host an event',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          EventsHeroHeader(
            userName: currentUser?.name ?? '?',
            avatarUrl: currentUser?.avatarUrl,
            onAvatarTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            onCalendarTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EventsCalendarScreen()),
            ),
            onNotificationsTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.label,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            tabs: const [
              Tab(key: Key('events-tab-upcoming'), text: 'Upcoming'),
              Tab(key: Key('events-tab-mine'), text: 'My events'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _UpcomingTab(),
                _MyEventsTab(onHost: _host),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _openEvent(BuildContext context, Event event) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));

/// Upcoming: search (on the server), category chips, then the list —
/// events near the user first.
class _UpcomingTab extends ConsumerStatefulWidget {
  const _UpcomingTab();

  @override
  ConsumerState<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends ConsumerState<_UpcomingTab>
    with AutomaticKeepAliveClientMixin {
  static const _debounceDuration = Duration(milliseconds: 400);

  final _scrollController = ScrollController();
  late final _searchController = TextEditingController(
    text: ref.read(eventsSearchProvider),
  );
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(eventsListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(eventsSearchProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final eventsAsync = ref.watch(eventsListProvider);
    final selectedCategory = ref.watch(eventsCategoryProvider);
    final categories =
        ref.watch(eventCategoriesProvider).valueOrNull ??
        const <EventCategory>[];
    final searching = ref.watch(eventsSearchProvider).isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            key: const Key('events-search-field'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search events',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CategoryChip(
                label: 'All',
                selected: selectedCategory == null,
                onTap: () =>
                    ref.read(eventsCategoryProvider.notifier).state = null,
              ),
              // The admin-managed list (EventCategoryController) — a new
              // category shows up here without an app update.
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _CategoryChip(
                  label: category.name,
                  selected: selectedCategory == category.name,
                  onTap: () => ref.read(eventsCategoryProvider.notifier).state =
                      category.name,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: eventsAsync.when(
            loading: () => const ShimmerCardList(thumbSize: 92, lines: 3),
            error: (error, _) => DiscoveryErrorView(
              error: error,
              onRetry: () => ref.read(eventsListProvider.notifier).refresh(),
            ),
            data: (state) {
              final events = state.events;
              if (events.isEmpty) {
                return ComingSoonView(
                  icon: Icons.event_outlined,
                  title: searching ? 'No events found' : 'No upcoming events',
                  message: searching
                      ? 'Try a different word — a title, place or host.'
                      : 'Check back soon, or host one yourself.',
                );
              }

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(eventsListProvider.notifier).refresh(),
                child: ListView.builder(
                  controller: _scrollController,
                  // Room at the bottom so the + button never covers the
                  // last event.
                  padding: const EdgeInsets.only(top: 4, bottom: 96),
                  itemCount: events.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= events.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final event = events[index];
                    return EventListTile(
                      event: event,
                      onTap: () => _openEvent(context, event),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// My events: what you're going to, hosting, saved and still drafting.
class _MyEventsTab extends ConsumerWidget {
  const _MyEventsTab({required this.onHost});

  final VoidCallback onHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      ref.invalidate(goingEventsProvider);
      ref.invalidate(hostingEventsProvider);
      ref.invalidate(savedEventsProvider);
      ref.invalidate(myDraftEventsProvider);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          _EventSection(
            key: const Key('my-events-going'),
            title: 'Going',
            empty: 'Events you RSVP to show up here.',
            events: ref.watch(goingEventsProvider),
          ),
          _EventSection(
            key: const Key('my-events-hosting'),
            title: 'Hosting',
            empty: 'Events you host show up here.',
            events: ref.watch(hostingEventsProvider),
            action: TextButton.icon(
              key: const Key('my-events-host'),
              onPressed: onHost,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Host an event'),
            ),
          ),
          _EventSection(
            key: const Key('my-events-saved'),
            title: 'Saved',
            empty: 'Tap the bookmark on an event to keep it here.',
            events: ref.watch(savedEventsProvider),
          ),
          _EventSection(
            key: const Key('my-events-drafts'),
            title: 'Drafts',
            empty: 'Events you start but don\'t publish wait here.',
            events: ref.watch(myDraftEventsProvider),
            // A draft opens in the editor, to finish and publish it.
            onOpen: (context, event) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateEventScreen(event: event),
                ),
              );
              ref.invalidate(myDraftEventsProvider);
              ref.invalidate(hostingEventsProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _EventSection extends StatelessWidget {
  const _EventSection({
    super.key,
    required this.title,
    required this.empty,
    required this.events,
    this.action,
    this.onOpen,
  });

  final String title;
  final String empty;
  final AsyncValue<List<Event>> events;
  final Widget? action;

  /// What tapping an event does — its page, unless set (drafts).
  final void Function(BuildContext context, Event event)? onOpen;

  @override
  Widget build(BuildContext context) {
    final list = events.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  list == null || list.isEmpty
                      ? title
                      : '$title (${list.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
        events.when(
          loading: () =>
              const ShimmerCardList(count: 2, thumbSize: 92, lines: 3),
          error: (_, _) => const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              "Couldn't load these — pull down to try again.",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    empty,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              : Column(
                  children: [
                    for (final event in items)
                      EventListTile(
                        event: event,
                        onTap: () => (onOpen ?? _openEvent)(context, event),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surfaceMuted,
      shape: const StadiumBorder(),
      side: BorderSide.none,
    );
  }
}
