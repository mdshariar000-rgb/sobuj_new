import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shobuj_mobile/models/uk_address.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/auth/register_screen.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../test/support/fake_api_client.dart';
import '../test/support/fake_secure_storage_service.dart';
import '../test/support/fake_uk_location_service.dart';

/// Sign-up's postcode-first address step on the simulator with sample
/// addresses — no network. Prints `SHOT <name>` for outside screenshots.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 250; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // ignore: avoid_print
    print('SHOT $name');
    await settle(tester, 3000);
  }

  testWidgets('postcode-first address at sign-up', (tester) async {
    final fakeClient = FakeApiClient()
      ..postcodeAddressesResult = const [
        AddressSuggestion(
          id: 'paf_1',
          address: 'Flat 1, 12 Cardigan Road, Leeds, LS6 3AA',
          line1: 'Flat 1',
          line2: '12 Cardigan Road',
          city: 'Leeds',
          county: 'West Yorkshire',
          postcode: 'LS6 3AA',
        ),
        AddressSuggestion(
          id: 'paf_2',
          address: 'Flat 2, 12 Cardigan Road, Leeds, LS6 3AA',
          line1: 'Flat 2',
          line2: '12 Cardigan Road',
          city: 'Leeds',
          county: 'West Yorkshire',
          postcode: 'LS6 3AA',
        ),
        AddressSuggestion(
          id: 'paf_3',
          address: '14 Cardigan Road, Leeds, LS6 3AA',
          line1: '14 Cardigan Road',
          city: 'Leeds',
          county: 'West Yorkshire',
          postcode: 'LS6 3AA',
        ),
        AddressSuggestion(
          id: 'paf_4',
          address: '16 Cardigan Road, Leeds, LS6 3AA',
          line1: '16 Cardigan Road',
          city: 'Leeds',
          county: 'West Yorkshire',
          postcode: 'LS6 3AA',
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RegisterScreen(),
        ),
      ),
    );
    await settle(tester, 2000);
    await shot(tester, '10-signup-postcode-only');

    await tester.enterText(
      find.byKey(const Key('address-postcode-field')),
      'ls6 3aa',
    );
    await tester.tap(find.byKey(const Key('address-find-button')));
    await settle(tester, 1500);
    await shot(tester, '11-signup-choose-address');

    await tester.tap(find.byKey(const Key('address-result-paf_2')));
    await settle(tester, 1200);
    await shot(tester, '12-signup-address-filled');
  });
}
