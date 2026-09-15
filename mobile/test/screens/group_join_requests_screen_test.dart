import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/group_join_request.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/groups/group_join_requests_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Group _buildGroup() {
  return Group(
    id: 1,
    name: 'Rare Seed Traders',
    slug: 'rare-seed-traders',
    visibility: 'private',
    myRole: 'admin',
    isMember: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpRequests(
  WidgetTester tester,
  FakeApiClient fakeClient,
) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: MaterialApp(home: GroupJoinRequestsScreen(group: _buildGroup())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an empty state when there are no pending requests', (
    tester,
  ) async {
    await _pumpRequests(tester, FakeApiClient());

    expect(find.text('No pending requests.'), findsOneWidget);
  });

  testWidgets('shows the real requesters, newest last', (tester) async {
    final fakeClient = FakeApiClient()
      ..groupJoinRequestsResult = PaginatedResponse(
        data: [
          GroupJoinRequest(
            id: 10,
            user: buildFakeUser(id: 5, name: 'Priya'),
            requestedAt: DateTime(2026, 1, 1),
          ),
          GroupJoinRequest(
            id: 11,
            user: buildFakeUser(id: 6, name: 'Tomas'),
            requestedAt: DateTime(2026, 1, 2),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpRequests(tester, fakeClient);

    expect(find.text('Priya'), findsOneWidget);
    expect(find.text('Tomas'), findsOneWidget);
  });

  testWidgets('approving a request calls the real API and removes it', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..groupJoinRequestsResult = PaginatedResponse(
        data: [
          GroupJoinRequest(
            id: 10,
            user: buildFakeUser(id: 5, name: 'Priya'),
            requestedAt: DateTime(2026, 1, 1),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpRequests(tester, fakeClient);

    await tester.tap(find.byKey(const Key('join-request-approve-10')));
    await tester.pumpAndSettle();

    expect(fakeClient.lastDecidedJoinRequestId, 10);
    expect(fakeClient.lastJoinRequestDecisionApprove, isTrue);
    expect(find.text('Priya'), findsNothing);
    expect(find.text('No pending requests.'), findsOneWidget);
  });

  testWidgets('rejecting a request calls the real API and removes it', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..groupJoinRequestsResult = PaginatedResponse(
        data: [
          GroupJoinRequest(
            id: 10,
            user: buildFakeUser(id: 5, name: 'Priya'),
            requestedAt: DateTime(2026, 1, 1),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpRequests(tester, fakeClient);

    await tester.tap(find.byKey(const Key('join-request-reject-10')));
    await tester.pumpAndSettle();

    expect(fakeClient.lastDecidedJoinRequestId, 10);
    expect(fakeClient.lastJoinRequestDecisionApprove, isFalse);
    expect(find.text('Priya'), findsNothing);
  });
}
