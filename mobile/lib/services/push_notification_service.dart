import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/notification_providers.dart';
import '../screens/notifications/notification_deep_link.dart';
import 'api_client.dart';

/// Wraps FCM device-token registration, foreground-message handling, and
/// notification-tap deep-linking behind one place — never called directly
/// by firebase_messaging elsewhere in the app.
class PushNotificationService {
  /// Requests the OS notification permission (a no-op prompt on Android
  /// below 13, a real runtime prompt on 13+ since POST_NOTIFICATIONS is a
  /// dangerous permission there) and, if a token comes back, registers it.
  /// Safe to call on every login/session-restore — the backend upserts.
  Future<void> requestPermissionAndRegister(ApiClient apiClient) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await apiClient.registerDeviceToken(token);
      }
    } catch (_) {
      // Best-effort — a missing/misconfigured Firebase project (or no
      // Play Services on the device) shouldn't block sign-in.
    }
  }

  /// Set up once at app start, independent of auth state — a token can
  /// refresh at any point during a long-lived session.
  void listenForTokenRefresh(ApiClient apiClient) {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      apiClient.registerDeviceToken(token).catchError((_) {});
    });
  }

  /// Called from AuthController.logout() while the auth token is still
  /// valid, so this device stops receiving this user's pushes once signed
  /// out (e.g. a shared/borrowed device).
  Future<void> unregister(ApiClient apiClient) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await apiClient.unregisterDeviceToken(token);
      }
    } catch (_) {
      // Best-effort — logout must still succeed locally either way.
    }
  }

  /// A push that arrived while the app was open and in the foreground.
  /// Chat-type messages (swap-offer/group) already arrive live via Reverb
  /// in this case, so showing a second banner here would double-notify —
  /// only like/comment/reply types get a SnackBar; every type bumps the
  /// unread badge.
  void handleForegroundMessage(ProviderContainer container, RemoteMessage message) {
    container.invalidate(unreadNotificationCountProvider);

    final type = message.data['type'] as String?;
    const chatTypes = {'swap_message_received', 'group_message_received'};
    if (type == null || chatTypes.contains(type)) return;

    final context = rootNavigatorKey.currentContext;
    final title = message.notification?.title;
    if (context == null || title == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(title)));
  }

  /// A notification the user tapped — either while the app was
  /// backgrounded (delivered via onMessageOpenedApp) or after being fully
  /// launched from a killed state by the tap (delivered via
  /// getInitialMessage()). Both call this same dispatcher.
  void handleNotificationTap(ProviderContainer container, RemoteMessage message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    openNotificationDataDeepLink(context, container.read(apiClientProvider), message.data);
  }
}

/// Lets notification-tap navigation (which fires outside any widget's own
/// BuildContext) push onto the app's real navigator — set as
/// MaterialApp.navigatorKey in main.dart.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(),
);
