import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/ai_conversation.dart';
import 'package:shobuj_mobile/models/ai_message.dart';
import 'package:shobuj_mobile/models/ai_message_role.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/subscription_status.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/agri_ai/agri_ai_paywall_screen.dart';
import 'package:shobuj_mobile/screens/agri_ai/agri_ai_screen.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

/// Lets a test hold the send request open, so it can assert on what's shown
/// while the request is still in flight — proving the user's own message
/// appears instantly rather than only once Gemini's reply comes back.
class _DelayedSendApiClient extends FakeApiClient {
  final _completer = Completer<AiConversation>();

  @override
  Future<AiConversation> sendAiMessage({
    int? conversationId,
    String? body,
    File? photo,
  }) {
    lastSendAiMessageConversationId = conversationId;
    return _completer.future;
  }

  void resolve(AiConversation conversation) => _completer.complete(conversation);
}

AiConversation _buildConversation({
  required int id,
  String? title,
  required List<AiMessage> messages,
}) {
  return AiConversation(
    id: id,
    title: title,
    messages: messages,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

AiMessage _buildMessage({
  required int id,
  required int conversationId,
  required AiMessageRole role,
  String? body,
}) {
  return AiMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    body: body,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpAgriAiScreen(
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
      child: const MaterialApp(home: AgriAiScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an empty state before any message is sent', (
    tester,
  ) async {
    await _pumpAgriAiScreen(tester, FakeApiClient());

    expect(find.text('Ask FloraAI anything'), findsOneWidget);
  });

  testWidgets(
    'shows the premium paywall instead of chat for an unsubscribed user',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..subscriptionStatusResult = const SubscriptionStatus(
          hasAccess: false,
          onTrial: false,
          cancelAtPeriodEnd: false,
        );

      await _pumpAgriAiScreen(tester, fakeClient);

      expect(find.byType(AgriAiPaywallScreen), findsOneWidget);
      expect(find.text('Ask FloraAI anything'), findsNothing);
    },
  );

  testWidgets('the send button is disabled until there is text to send', (
    tester,
  ) async {
    await _pumpAgriAiScreen(tester, FakeApiClient());

    final sendButtonFinder = find.ancestor(
      of: find.byIcon(Icons.arrow_upward),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(sendButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();

    expect(tester.widget<IconButton>(sendButtonFinder).onPressed, isNotNull);
  });

  testWidgets(
    'renders the reply\'s light markdown as formatted text, not raw syntax',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..sendAiMessageResult = _buildConversation(
          id: 1,
          messages: [
            _buildMessage(
              id: 1,
              conversationId: 1,
              role: AiMessageRole.user,
              body: 'What can I do about yellowing leaves?',
            ),
            _buildMessage(
              id: 2,
              conversationId: 1,
              role: AiMessageRole.assistant,
              body:
                  '**Diagnosis:** Likely nitrogen deficiency.\n'
                  '- Apply a balanced fertilizer\n'
                  '- Water deeply once a week',
            ),
          ],
        );

      await _pumpAgriAiScreen(tester, fakeClient);

      await tester.enterText(
        find.byType(TextField),
        'What can I do about yellowing leaves?',
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.textContaining('**'), findsNothing);
      expect(
        find.text('Diagnosis: Likely nitrogen deficiency.'),
        findsOneWidget,
      );
      expect(find.text('Apply a balanced fertilizer'), findsOneWidget);
      expect(find.text('Water deeply once a week'), findsOneWidget);
    },
  );

  testWidgets('sending a message shows the user message and the reply', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..sendAiMessageResult = _buildConversation(
        id: 1,
        messages: [
          _buildMessage(
            id: 1,
            conversationId: 1,
            role: AiMessageRole.user,
            body: 'Why are my tomato leaves curling?',
          ),
          _buildMessage(
            id: 2,
            conversationId: 1,
            role: AiMessageRole.assistant,
            body: 'That can be heat stress — keep the soil consistently moist.',
          ),
        ],
      );

    await _pumpAgriAiScreen(tester, fakeClient);

    await tester.enterText(
      find.byType(TextField),
      'Why are my tomato leaves curling?',
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('Why are my tomato leaves curling?'), findsOneWidget);
    expect(
      find.text('That can be heat stress — keep the soil consistently moist.'),
      findsOneWidget,
    );
    expect(fakeClient.lastSendAiMessageConversationId, isNull);
  });

  testWidgets(
    "a sent message appears instantly, before Gemini's reply resolves",
    (tester) async {
      final fakeClient = _DelayedSendApiClient();

      await _pumpAgriAiScreen(tester, fakeClient);

      await tester.enterText(find.byType(TextField), 'Why are the leaves wilting?');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      // The optimistic bubble is already showing — Gemini hasn't replied yet.
      expect(find.text('Why are the leaves wilting?'), findsOneWidget);

      fakeClient.resolve(
        _buildConversation(
          id: 1,
          messages: [
            _buildMessage(
              id: 1,
              conversationId: 1,
              role: AiMessageRole.user,
              body: 'Why are the leaves wilting?',
            ),
            _buildMessage(
              id: 2,
              conversationId: 1,
              role: AiMessageRole.assistant,
              body: 'Likely underwatering — check the soil moisture.',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Why are the leaves wilting?'), findsOneWidget);
      expect(
        find.text('Likely underwatering — check the soil moisture.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows the server error message when sending fails', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..sendAiMessageError = const ApiException(
        message: 'Something went wrong talking to FloraAI.',
        statusCode: 500,
      );

    await _pumpAgriAiScreen(tester, fakeClient);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong talking to FloraAI.'),
      findsOneWidget,
    );
  });

  testWidgets('opening a past conversation from history loads its messages', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..aiConversationsResult = PaginatedResponse(
        data: [_buildConversation(id: 5, title: 'Aphid trouble', messages: [])],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..aiConversationResult = _buildConversation(
        id: 5,
        title: 'Aphid trouble',
        messages: [
          _buildMessage(
            id: 10,
            conversationId: 5,
            role: AiMessageRole.user,
            body: 'How do I get rid of aphids?',
          ),
        ],
      );

    await _pumpAgriAiScreen(tester, fakeClient);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('Aphid trouble'), findsOneWidget);

    await tester.tap(find.text('Aphid trouble'));
    await tester.pumpAndSettle();

    expect(find.text('How do I get rid of aphids?'), findsOneWidget);
  });
}
