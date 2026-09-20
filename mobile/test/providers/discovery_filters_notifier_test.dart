import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/config/app_config.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/providers/discovery_providers.dart';

void main() {
  group('DiscoveryFiltersNotifier', () {
    test('starts with the default filters', () {
      final notifier = DiscoveryFiltersNotifier();

      expect(notifier.state.searchTerm, '');
      expect(notifier.state.category, isNull);
      expect(notifier.state.transactionType, isNull);
      expect(notifier.state.radiusKm, AppConfig.defaultRadiusKm);
    });

    test('setSearchTerm updates only the search term', () {
      final notifier = DiscoveryFiltersNotifier()..setSearchTerm('tomato');

      expect(notifier.state.searchTerm, 'tomato');
      expect(notifier.state.radiusKm, AppConfig.defaultRadiusKm);
    });

    test('toggleCategory selects a category on first tap', () {
      final notifier = DiscoveryFiltersNotifier()
        ..toggleCategory('Seeds & Scions');

      expect(notifier.state.category, 'Seeds & Scions');
    });

    test(
      'toggleCategory clears the category when tapping the selected one again',
      () {
        final notifier = DiscoveryFiltersNotifier()
          ..toggleCategory('Seeds & Scions')
          ..toggleCategory('Seeds & Scions');

        expect(notifier.state.category, isNull);
      },
    );

    test('toggleCategory switches to a different category directly', () {
      final notifier = DiscoveryFiltersNotifier()
        ..toggleCategory('Seeds & Scions')
        ..toggleCategory('Live Plants & Saplings');

      expect(notifier.state.category, 'Live Plants & Saplings');
    });

    test('toggleTransactionType behaves the same way as toggleCategory', () {
      final notifier = DiscoveryFiltersNotifier()
        ..toggleTransactionType(TransactionType.swap)
        ..toggleTransactionType(TransactionType.swap);

      expect(notifier.state.transactionType, isNull);
    });

    test('setRadiusKm updates only the radius', () {
      final notifier = DiscoveryFiltersNotifier()
        ..toggleCategory('Seeds & Scions')
        ..setRadiusKm(25);

      expect(notifier.state.radiusKm, 25);
      expect(notifier.state.category, 'Seeds & Scions');
    });
  });
}
