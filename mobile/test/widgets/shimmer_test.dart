import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/groups/groups_screen.dart';
import 'package:shobuj_mobile/widgets/shimmer.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

/// Groups that never arrive, so the screen stays in its loading state.
class _SlowGroupsClient extends FakeApiClient {
  final _never = Completer<PaginatedResponse<Group>>();

  @override
  Future<PaginatedResponse<Group>> groups({
    String? search,
    String? category,
    String? membership,
    int page = 1,
  }) => _never.future;
}

void main() {
  testWidgets('every skeleton fits a phone screen without overflowing', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    for (final skeleton in const <Widget>[
      ShimmerCardList(),
      ShimmerCardList(thumbSize: 92, lines: 3),
      ShimmerListingGrid(rows: 3),
      ShimmerPostList(),
      ShimmerChat(),
      ShimmerProfile(),
    ]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: skeleton)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: '$skeleton');
    }
  });

  testWidgets('a loading list shows its skeleton instead of a spinner', (
    tester,
  ) async {
    final fakeStorage = FakeSecureStorageService();
    await fakeStorage.saveToken('existing-token');
    final fakeClient = _SlowGroupsClient()..meResult = buildFakeUser();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          secureStorageProvider.overrideWithValue(fakeStorage),
        ],
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );
    // The shimmer never stops moving, so pump a few frames rather than
    // waiting for the screen to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('shimmer-card-list')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
