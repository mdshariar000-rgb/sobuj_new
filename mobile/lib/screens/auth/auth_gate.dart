import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../shell/agro_hub_shell.dart';
import '../splash/splash_screen.dart';
import 'login_screen.dart';

/// The app's root widget: shows a splash while restoring a stored session,
/// then either the Agro Hub tab shell (signed in) or the Login screen (not)
/// — and switches between them automatically whenever auth state changes, so
/// no screen needs to manually navigate on login/logout.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const SplashScreen(),
      error: (_, _) => const LoginScreen(),
      data: (user) => user == null ? const LoginScreen() : const AgroHubShell(),
    );
  }
}
