import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/shell_providers.dart';
import '../../../theme/app_colors.dart';
import '../grow_now_screen.dart';
import '../weather_screen.dart';

/// Bottom-nav tab indexes — see AgroHubShell.
const _groupsTabIndex = 1;
const _eventsTabIndex = 2;
const _marketplaceTabIndex = 3;

/// The Home tab's "Quick access" grid: shortcuts to the seasonal sowing
/// guide, local weather, and the Groups / Events / Marketplace tabs —
/// compact tiles, three to a row, so "Picked for you" still shows on the
/// first screen.
class QuickAccessSection extends ConsumerWidget {
  const QuickAccessSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    void openTab(int index) =>
        ref.read(selectedTabIndexProvider.notifier).state = index;

    final tiles = [
      _QuickAccessTile(
        key: const Key('quick-access-grow-now'),
        icon: Icons.spa_outlined,
        title: 'What to grow now',
        onTap: () => push(const GrowNowScreen()),
      ),
      _QuickAccessTile(
        key: const Key('quick-access-weather'),
        icon: Icons.wb_sunny_outlined,
        title: 'Weather',
        onTap: () => push(const WeatherScreen()),
      ),
      _QuickAccessTile(
        key: const Key('quick-access-community'),
        icon: Icons.groups_outlined,
        title: 'Community',
        onTap: () => openTab(_groupsTabIndex),
      ),
      _QuickAccessTile(
        key: const Key('quick-access-events'),
        icon: Icons.event_outlined,
        title: 'Events',
        onTap: () => openTab(_eventsTabIndex),
      ),
      _QuickAccessTile(
        key: const Key('quick-access-marketplace'),
        icon: Icons.storefront_outlined,
        title: 'Marketplace',
        onTap: () => openTab(_marketplaceTabIndex),
      ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Text(
                'QUICK ACCESS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth / 3;
                return Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final tile in tiles)
                      SizedBox(width: tileWidth, child: tile),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
