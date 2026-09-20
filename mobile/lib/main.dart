import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/core_providers.dart';
import 'screens/auth/auth_gate.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A single explicit ProviderContainer (rather than a plain ProviderScope)
  // so push-notification wiring below — which fires before any widget
  // exists, e.g. a tap that launches the app from a killed state — has
  // something to read providers from.
  final container = ProviderContainer();

  try {
    await Firebase.initializeApp();
    _wireUpPushNotifications(container);
  } catch (_) {
    // No Firebase project configured for this build yet (e.g. local dev
    // before google-services.json is in place) — the rest of the app still
    // works, it just won't receive push notifications.
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const ShobujApp()),
  );
}

void _wireUpPushNotifications(ProviderContainer container) {
  final apiClient = container.read(apiClientProvider);
  final pushService = container.read(pushNotificationServiceProvider);

  pushService.listenForTokenRefresh(apiClient);

  FirebaseMessaging.onMessage.listen(
    (message) => pushService.handleForegroundMessage(container, message),
  );
  FirebaseMessaging.onMessageOpenedApp.listen(
    (message) => pushService.handleNotificationTap(container, message),
  );
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      pushService.handleNotificationTap(container, message);
    }
  });
}

class ShobujApp extends StatelessWidget {
  const ShobujApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Agro Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
