import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/group.dart';
import 'core_providers.dart';

/// True from the moment a new account is being registered until the user
/// finishes (or skips) onboarding — AuthGate shows the onboarding flow
/// instead of the tab shell while it's set. Set *before* the register call,
/// so the shell never flashes up first. Not persisted: an app restart
/// mid-onboarding just lands on Home.
final needsOnboardingProvider = StateProvider<bool>((ref) => false);

final suggestedUsersProvider = FutureProvider.autoDispose<List<AppUser>>(
  (ref) => ref.watch(apiClientProvider).suggestedUsers(),
);

final suggestedGroupsProvider = FutureProvider.autoDispose<SuggestedGroups>(
  (ref) => ref.watch(apiClientProvider).suggestedGroups(),
);
