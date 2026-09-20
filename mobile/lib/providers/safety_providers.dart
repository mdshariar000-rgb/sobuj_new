import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'core_providers.dart';

/// The accounts the signed-in user has blocked (first page, up to 50) — backs
/// the Profile → Blocked users screen.
final blockedUsersProvider = FutureProvider.autoDispose<List<AppUser>>((
  ref,
) async {
  final page = await ref.watch(apiClientProvider).blockedUsers();
  return page.data;
});
