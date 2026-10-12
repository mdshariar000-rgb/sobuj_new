import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/address_screen.dart';
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
      data: (user) {
        if (user == null) return const LoginScreen();
        // Accounts made before the address was required add it first.
        if (user.needsAddress) return const AddressScreen(required: true);
        // A brand-new account gets the follow/join onboarding first.
        if (ref.watch(needsOnboardingProvider)) return const OnboardingScreen();
        return const AgroHubShell();
      },
    );
  }
}
