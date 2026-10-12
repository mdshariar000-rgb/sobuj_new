import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shell_providers.dart';
import '../discovery/discovery_screen.dart';
import '../events/events_screen.dart';
import '../groups/groups_screen.dart';
import '../home/home_feed_screen.dart';

/// The signed-in app's root: a 4-tab bottom nav shell (Home / Groups /
/// Events / Marketplace). Marketplace is Discovery — the
/// pre-pivot marketplace screen — now reintroduced into navigation;
/// Profile moved to a tappable avatar in each tab's own header instead of
/// taking a nav slot.
class AgroHubShell extends ConsumerWidget {
  const AgroHubShell({super.key});

  static const _tabs = [
    HomeFeedScreen(),
    GroupsScreen(),
    EventsScreen(),
    DiscoveryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            ref.read(selectedTabIndexProvider.notifier).state = index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Marketplace',
          ),
        ],
      ),
    );
  }
}
