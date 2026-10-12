import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/sowing_guide_month.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/home/grow_now_screen.dart';
import 'package:shobuj_mobile/services/api_exception.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../support/fake_api_client.dart';

Future<void> _pump(WidgetTester tester, FakeApiClient fakeClient) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fakeClient)],
      child: MaterialApp(theme: AppTheme.light(), home: const GrowNowScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

List<SowingGuideMonth> _guideWithThisMonth({
  required List<String> outdoors,
  required List<String> underCover,
}) {
  final thisMonth = DateTime.now().month;
  return [
    for (var month = 1; month <= 12; month++)
      SowingGuideMonth(
        month: month,
        outdoors: month == thisMonth ? outdoors : const ['Wrong month'],
        underCover: month == thisMonth ? underCover : const ['Wrong month'],
      ),
  ];
}

void main() {
  testWidgets('shows this month’s plants from the admin-managed guide', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeApiClient()
        ..sowingGuideResult = _guideWithThisMonth(
          outdoors: ['Garlic', 'Hardy peas'],
          underCover: ['Sweet peas'],
        ),
    );

    expect(find.text('Sow or plant outdoors'), findsOneWidget);
    expect(find.text('Garlic'), findsOneWidget);
    expect(find.text('Hardy peas'), findsOneWidget);
    expect(find.text('Start under cover'), findsOneWidget);
    expect(find.text('Sweet peas'), findsOneWidget);
    expect(find.text('Wrong month'), findsNothing);
  });

  testWidgets('hides an empty list and says so when the month is empty', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeApiClient()
        ..sowingGuideResult = _guideWithThisMonth(outdoors: [], underCover: []),
    );

    expect(find.text('Sow or plant outdoors'), findsNothing);
    expect(find.text('Start under cover'), findsNothing);
    expect(find.byKey(const Key('grow-now-empty')), findsOneWidget);
  });

  testWidgets('shows an error with a working retry', (tester) async {
    final fakeClient = FakeApiClient()
      ..sowingGuideError = const ApiException(message: 'No connection.');
    await _pump(tester, fakeClient);

    expect(find.text('No connection.'), findsOneWidget);

    fakeClient.sowingGuideError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Sow or plant outdoors'), findsOneWidget);
  });
}
