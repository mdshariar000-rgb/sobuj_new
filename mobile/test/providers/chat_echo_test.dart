import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/swap_message.dart';
import 'package:shobuj_mobile/providers/auth_providers.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/discovery_providers.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

void main() {
  test('a realtime echo of my own message replaces its "Sending…" bubble '
      'instead of showing it twice', () async {
    final me = buildFakeUser(id: 1, name: 'Me');
    final sent = SwapMessage(
      id: 50,
      swapOfferId: 1,
      isSystemEvent: false,
      body: 'Is this still available?',
      sender: me,
      createdAt: DateTime.utc(2026, 10, 12, 9),
    );
    final gate = Completer<void>();
    final fakeClient = FakeApiClient()
      ..meResult = me
      ..swapOfferMessagesResult = const PaginatedResponse(
        data: [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
      )
      ..sendSwapOfferMessageResult = sent
      ..sendSwapOfferMessageGate = gate;
    final fakeStorage = FakeSecureStorageService();
    await fakeStorage.saveToken('existing-token');
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      swapOfferMessagesProvider(1),
      (_, _) {},
    );
    addTearDown(subscription.close);
    for (var i = 0; i < 20; i++) {
      if (container.read(authControllerProvider).valueOrNull != null &&
          container.read(swapOfferMessagesProvider(1)).hasValue) {
        break;
      }
      await Future<void>.delayed(Duration.zero);
    }
    final notifier = container.read(swapOfferMessagesProvider(1).notifier);
    List<SwapMessage> messages() =>
        container.read(swapOfferMessagesProvider(1)).requireValue;

    final sending = notifier.sendMessage(body: 'Is this still available?');
    expect(messages().single.isPending, isTrue);

    // The server's push arrives before the send request returns.
    notifier.receiveMessage(sent);
    expect(messages().map((m) => m.id), [50]);

    gate.complete();
    await sending;
    expect(messages().map((m) => m.id), [50]);
  });
}
