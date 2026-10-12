import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shobuj_mobile/main.dart' as app;

/// Launches the real app on a device/simulator (needs a signed-in session
/// already stored on it) and taps every bottom-nav tab.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom nav switches tabs on a real device', (tester) async {
    app.main();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(NavigationBar).evaluate().isNotEmpty) break;
    }
    expect(find.byType(NavigationBar), findsOneWidget);

    for (final (index, label) in [
      (1, 'Groups'),
      (2, 'Events'),
      (3, 'Marketplace'),
      (0, 'Home'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, index, reason: 'after tapping $label');
      final stack = tester.widget<IndexedStack>(
        find
                .ancestor(
                  of: find.byType(NavigationBar),
                  matching: find.byType(Scaffold),
                )
                .evaluate()
                .isEmpty
            ? find.byType(IndexedStack).first
            : find.byType(IndexedStack).first,
      );
      expect(stack.index, index, reason: 'screen after tapping $label');
    }
  });
}
