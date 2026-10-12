import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/group.dart';
import '../../providers/core_providers.dart';
import '../../providers/group_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/shimmer.dart';

/// Shown once, straight after registering: join a few public groups. Can be
/// skipped; finishing (or skipping) lands on Home.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Joins/leaves made on this screen, by group id — on top of the
  /// server's is_member, which is already true for the groups registration
  /// auto-joined.
  final _joinedOverrides = <int, bool>{};

  /// Groups with a join request in flight — their button is
  /// disabled until it settles.
  final _busy = <String>{};

  Future<void> _toggleJoin(Group group) async {
    final key = 'group-${group.id}';
    if (_busy.contains(key)) return;
    final wasJoined = _isJoined(group);
    setState(() {
      _busy.add(key);
      _joinedOverrides[group.id] = !wasJoined;
    });
    try {
      final api = ref.read(apiClientProvider);
      wasJoined
          ? await api.leaveGroup(group.id)
          : await api.joinGroup(group.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _joinedOverrides[group.id] = wasJoined);
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  bool _isJoined(Group group) =>
      _joinedOverrides[group.id] ?? group.isMember ?? false;

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _finish() {
    // Groups was built before any of these joins.
    ref.invalidate(groupsListProvider);
    ref.read(needsOnboardingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join a few groups',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Meet growers near you and share what you\'re growing.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _GroupsList(
                isJoined: _isJoined,
                busy: _busy,
                onToggle: _toggleJoin,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    key: const Key('onboarding-skip'),
                    onPressed: _finish,
                    child: const Text('Skip for now'),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('onboarding-next'),
                    onPressed: _finish,
                    // The theme's full-width minimumSize can't lay out in a Row.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                    ),
                    child: const Text('Get started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsList extends ConsumerWidget {
  const _GroupsList({
    required this.isJoined,
    required this.busy,
    required this.onToggle,
  });

  final bool Function(Group group) isJoined;
  final Set<String> busy;
  final ValueChanged<Group> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(suggestedGroupsProvider)
        .when(
          loading: () => const ShimmerCardList(thumbSize: 44, roundThumb: true),
          error: (_, _) => _LoadError(
            onRetry: () => ref.invalidate(suggestedGroupsProvider),
          ),
          data: (suggested) {
            final groups = suggested.groups;
            final city = suggested.city;
            if (groups.isEmpty) {
              return const _EmptyNote(
                'No public groups to suggest yet — you can browse Groups later.',
              );
            }
            final local = groups.where((g) => g.isLocal ?? false).toList();
            final others = groups.where((g) => !(g.isLocal ?? false)).toList();

            Widget tile(Group group) {
              final details = [
                if (city != null && (group.localMembersCount ?? 0) > 0)
                  '${group.localMembersCount} in $city'
                else
                  ?group.category,
                if (group.membersCount != null)
                  '${group.membersCount} member${group.membersCount == 1 ? '' : 's'}',
              ].join(' · ');
              return ListTile(
                key: Key('suggested-group-${group.id}'),
                leading: UserAvatar(
                  name: group.name,
                  avatarUrl: group.avatarUrl ?? group.coverImageUrl,
                  radius: 22,
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: details.isEmpty
                    ? null
                    : Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: _ToggleButton(
                  key: Key('join-${group.id}'),
                  active: isJoined(group),
                  activeLabel: 'Joined',
                  inactiveLabel: 'Join',
                  onPressed: busy.contains('group-${group.id}')
                      ? null
                      : () => onToggle(group),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (city != null)
                  _SectionHeading(
                    key: const Key('onboarding-city-heading'),
                    icon: Icons.location_on,
                    text: 'Groups in $city',
                  ),
                if (city != null && local.isEmpty)
                  Padding(
                    key: const Key('onboarding-no-city-groups'),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                      'No groups for $city yet. You can ask for one from the '
                      'Groups tab later.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                for (final (i, group) in local.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  tile(group),
                ],
                if (others.isNotEmpty) ...[
                  _SectionHeading(
                    icon: Icons.groups_outlined,
                    text: city != null ? 'Popular groups' : 'Suggested groups',
                  ),
                  for (final (i, group) in others.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    tile(group),
                  ],
                ],
              ],
            );
          },
        );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    super.key,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.onPressed,
  });

  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const size = Size(104, 36);
    return active
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.check, size: 16),
            label: Text(activeLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(minimumSize: size),
            child: Text(inactiveLabel),
          );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load suggestions."),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
