import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/providers/auth_providers.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/profile/edit_profile_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

AppUser _buildUser({List<String> growingInterests = const []}) {
  return AppUser(
    id: 1,
    name: 'Maya Lin',
    email: 'maya@example.com',
    username: 'mayagrows',
    bio: 'Backyard grower',
    locationLabel: 'Napa Valley, CA',
    growingInterests: growingInterests,
    showHandoverRadius: true,
    ratingAvg: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Waits for the auth session to finish restoring in a standalone
/// [ProviderContainer] before mounting [EditProfileScreen] — mirroring real
/// navigation, where this screen is only ever reached (via Profile) after
/// auth has already resolved. Mounting it before that resolves would leave
/// its controllers seeded from a still-null user, same as it would in the
/// real app.
Future<FakeApiClient> _pump(WidgetTester tester, {AppUser? user}) async {
  final fakeClient = FakeApiClient()..meResult = user ?? _buildUser();
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');

  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(fakeClient),
      secureStorageProvider.overrideWithValue(fakeStorage),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.notifier).refresh();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: EditProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fakeClient;
}

/// Scrolls the screen's scrollable until [finder] is mounted — needed
/// because a plain (non-builder) ListView still lazily mounts its sliver
/// children by viewport, so a field far down the now-taller (card-grouped)
/// form isn't in the element tree until scrolled near it, same as a real
/// device would need a real scroll to reveal it.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<String> _textOf(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _scrollTo(tester, finder);
  return tester.widget<TextFormField>(finder).controller!.text;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
}

void main() {
  testWidgets('pre-fills fields from the real signed-in user', (tester) async {
    await _pump(tester, user: _buildUser(growingInterests: ['Tomatoes']));

    expect(
      await _textOf(tester, const Key('edit-profile-name-field')),
      'Maya Lin',
    );
    expect(
      await _textOf(tester, const Key('edit-profile-username-field')),
      'mayagrows',
    );
    // Checked in on-screen top-to-bottom order — _scrollTo only scrolls
    // forward, matching how a real user would scroll down through the form.
    final emailFinder = find.descendant(
      of: find.byKey(const Key('edit-profile-email-field')),
      matching: find.byType(EditableText),
    );
    await _scrollTo(tester, emailFinder);
    final emailEditable = tester.widget<EditableText>(emailFinder);
    expect(emailEditable.controller.text, 'maya@example.com');
    expect(
      await _textOf(tester, const Key('edit-profile-bio-field')),
      'Backyard grower',
    );
    expect(
      await _textOf(tester, const Key('edit-profile-location-field')),
      'Napa Valley, CA',
    );
    await _scrollTo(tester, find.text('Tomatoes'));
    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.textContaining('Zone 9b'), findsNothing);
  });

  testWidgets('email field is present but cannot be edited', (tester) async {
    await _pump(tester);

    final emailFinder = find.descendant(
      of: find.byKey(const Key('edit-profile-email-field')),
      matching: find.byType(EditableText),
    );
    await _scrollTo(tester, emailFinder);
    final editable = tester.widget<EditableText>(emailFinder);
    expect(editable.readOnly, isTrue);
  });

  testWidgets('adding a growing interest chip and saving submits it', (
    tester,
  ) async {
    final fakeClient = await _pump(tester);
    fakeClient.updateProfileResult = _buildUser(
      growingInterests: ['Peppers'],
    );

    final interestFieldFinder = find.byKey(
      const Key('edit-profile-interest-field'),
    );
    await _scrollTo(tester, interestFieldFinder);
    await tester.enterText(interestFieldFinder, 'Peppers');
    await _tapVisible(
      tester,
      find.byKey(const Key('edit-profile-add-interest-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Peppers'), findsOneWidget);

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    await tester.pumpAndSettle();

    expect(
      fakeClient.lastUpdateProfileArgs?['growingInterests'],
      contains('Peppers'),
    );
  });

  testWidgets(
    'toggling Community Handover Radius off and saving sends the real flag',
    (tester) async {
      final fakeClient = await _pump(tester);
      fakeClient.updateProfileResult = _buildUser();

      await _tapVisible(
        tester,
        find.byKey(const Key('edit-profile-handover-switch')),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save Changes'),
      );
      await tester.pumpAndSettle();

      expect(fakeClient.lastUpdateProfileArgs?['showHandoverRadius'], isFalse);
    },
  );

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await _pump(
        tester,
        user: _buildUser(
          growingInterests: [
            'Tomatoes',
            'Peppers',
            'Squash',
            'Basil',
            'Zucchini',
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
