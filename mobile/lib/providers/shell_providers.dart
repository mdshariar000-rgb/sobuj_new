import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which of the 5 Agro Hub bottom-nav tabs is currently showing. Local UI
/// state only — not persisted, mirroring [viewModeProvider]'s pattern for
/// Discovery's list/map toggle.
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);
