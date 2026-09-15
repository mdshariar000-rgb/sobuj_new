import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/event.dart';
import '../../models/event_category.dart';
import '../../providers/auth_providers.dart';
import '../../providers/event_providers.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../shell/widgets/coming_soon_view.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import 'events_calendar_screen.dart';
import 'widgets/event_card.dart';
import 'widgets/events_hero_header.dart';

/// The Events tab: upcoming published events, with a "Host an Event" action
/// leading to the dedicated create-event screen.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(eventsListProvider.notifier).loadMore();
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  List<Event> _applyFilters(List<Event> events) {
    if (_searchQuery.isEmpty) return events;
    return events
        .where(
          (event) =>
              event.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsListProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final userName = currentUser?.name ?? '?';
    final selectedCategory = ref.watch(eventsCategoryProvider);
    final categoriesAsync = ref.watch(eventCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'events-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateEventScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Host an Event'),
      ),
      body: Column(
        children: [
          EventsHeroHeader(
            userName: userName,
            avatarUrl: currentUser?.avatarUrl,
            onAvatarTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            onCalendarTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EventsCalendarScreen()),
            ),
            onNotificationsTap: () => _comingSoon('Notifications'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    decoration: const InputDecoration(
                      hintText:
                          'Search farming workshops, field days, webinars...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _comingSoon('Advanced filters'),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FormatChip(
                  icon: Icons.grid_view_rounded,
                  label: 'All Events',
                  selected: selectedCategory == null,
                  onTap: () =>
                      ref.read(eventsCategoryProvider.notifier).state = null,
                ),
                // The rest come from the admin-managed list (see
                // EventCategoryResource/EventCategoryController on the
                // backend) — an admin adding or renaming a category shows
                // up here with no app update needed.
                for (final category
                    in categoriesAsync.valueOrNull ??
                        const <EventCategory>[]) ...[
                  const SizedBox(width: 8),
                  _FormatChip(
                    label: category.name,
                    selected: selectedCategory == category.name,
                    onTap: () =>
                        ref.read(eventsCategoryProvider.notifier).state =
                            category.name,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (state) {
                final events = _applyFilters(state.events);
                if (events.isEmpty) {
                  return const ComingSoonView(
                    icon: Icons.event_outlined,
                    title: 'No upcoming events',
                    message: 'Check back soon, or host one yourself.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(eventsListProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 88),
                    itemCount: events.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= events.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final event = events[index];
                      return EventCard(
                        event: event,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EventDetailScreen(event: event),
                          ),
                        ),
                      );
                    },
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

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textDark,
            )
          : null,
      label: Text(label),
      selected: selected,
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
