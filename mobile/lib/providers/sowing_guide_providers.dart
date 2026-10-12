import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sowing_guide_month.dart';
import 'core_providers.dart';

/// All 12 months of the admin-managed sowing guide — the screen picks the
/// current month itself.
final sowingGuideProvider = FutureProvider.autoDispose<List<SowingGuideMonth>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.sowingGuide();
});
