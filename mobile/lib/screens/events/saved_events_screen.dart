import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/event.dart';
import '../../providers/event_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'event_detail_screen.dart';
import 'widgets/event_card.dart';

/// Real "Saved Events" — every event the user has tapped the bookmark icon
/// on (GET /events/saved), not a client-side-only bookmark. Includes events
/// that already ended, since a saved event is still something the user
/// chose to keep.
class SavedEventsScreen extends ConsumerWidget {
  const SavedEventsScreen({super.key});

  Future<void> _unsave(BuildContext context, WidgetRef ref, Event event) async {
    try {
      await ref.read(savedEventsProvider.notifier).unsave(event);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Saved Events')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved events yet — tap the bookmark on an event to '
                  'save it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(savedEventsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return EventCard(
                  event: event,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: event),
                    ),
                  ),
                  onToggleSave: () => _unsave(context, ref, event),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
