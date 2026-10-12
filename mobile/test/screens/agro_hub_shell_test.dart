import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/geo_point.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/location_providers.dart';
import 'package:shobuj_mobile/providers/shell_providers.dart';
import 'package:shobuj_mobile/screens/auth/auth_gate.dart';
import 'package:shobuj_mobile/screens/discovery/discovery_screen.dart';
import 'package:shobuj_mobile/screens/events/events_screen.dart';
import 'package:shobuj_mobile/screens/groups/groups_screen.dart';
import 'package:shobuj_mobile/screens/home/home_feed_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

const _fakeLocation = GeoPoint(latitude: 53.8173, longitude: -1.5776);

void main() {
  testWidgets('each bottom-nav tab switches to its screen', (tester) async {
    final fakeClient = FakeApiClient()..meResult = buildFakeUser();
    final fakeStorage = FakeSecureStorageService();
    await fakeStorage.saveToken('existing-token');

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
        accountLocationProvider.overrideWith((ref) async => _fakeLocation),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    final tabs = <String, Type>{
      'Groups': GroupsScreen,
      'Events': EventsScreen,
      'Marketplace': DiscoveryScreen,
      'Home': HomeFeedScreen,
    };
    var index = 0;
    for (final MapEntry(key: label, value: screen) in tabs.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(selectedTabIndexProvider),
        ['Home', 'Groups', 'Events', 'Marketplace'].indexOf(label),
        reason: 'tapping $label',
      );
      final stack = tester.widget<IndexedStack>(
        find.byType(IndexedStack).first,
      );
      expect(stack.index, container.read(selectedTabIndexProvider));
      expect(find.byType(screen, skipOffstage: true), findsOneWidget);
      index++;
    }
    expect(index, 4);
  });
}
