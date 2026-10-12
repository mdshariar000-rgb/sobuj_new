import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/sowing_guide_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shimmer.dart';

/// "What can you grow now?" from Home's quick access list — this month's
/// entry from the admin-managed sowing guide (GET /sowing-guide).
class GrowNowScreen extends ConsumerWidget {
  const GrowNowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final guideAsync = ref.watch(sowingGuideProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('What can you grow now?')),
      body: guideAsync.when(
        loading: () => const ShimmerCardList(thumbSize: 44),
        error: (error, _) => _ErrorView(
          message: error is ApiException
              ? error.message
              : 'Couldn’t load the sowing guide.',
          onRetry: () => ref.invalidate(sowingGuideProvider),
        ),
        data: (months) {
          final guide = months.where((m) => m.month == now.month).firstOrNull;
          final outdoors = guide?.outdoors ?? const <String>[];
          final underCover = guide?.underCover ?? const <String>[];

          return RefreshIndicator(
            onRefresh: () => ref.refresh(sowingGuideProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Sowing in ${DateFormat.MMMM().format(now)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'A general guide for UK gardens — timings shift a few weeks '
                  'with your local weather.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                if (outdoors.isEmpty && underCover.isEmpty)
                  const Padding(
                    key: Key('grow-now-empty'),
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Nothing listed for this month yet — check back soon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                if (outdoors.isNotEmpty)
                  _GuideCard(
                    icon: Icons.grass,
                    title: 'Sow or plant outdoors',
                    items: outdoors,
                  ),
                if (outdoors.isNotEmpty && underCover.isNotEmpty)
                  const SizedBox(height: 12),
                if (underCover.isNotEmpty)
                  _GuideCard(
                    icon: Icons.home_outlined,
                    title: 'Start under cover',
                    items: underCover,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  Chip(
                    label: Text(item),
                    backgroundColor: AppColors.surfaceMuted,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
