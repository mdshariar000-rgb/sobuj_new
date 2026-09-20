import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/notification_bell_button.dart';
import '../../../widgets/user_avatar.dart';

/// The Home tab's green hero header: avatar + a truthful role eyebrow (the
/// user's own growing setup, not an invented title), the "Agro Hub" wordmark,
/// and a time-of-day greeting. Search has no backend yet, so it's wired as
/// a "coming soon" tap; notifications opens the real inbox.
class HomeHeroHeader extends StatelessWidget {
  const HomeHeroHeader({
    super.key,
    required this.userName,
    this.avatarUrl,
    this.roleLabel,
    required this.onAvatarTap,
    required this.onSearchTap,
    required this.onNotificationsTap,
  });

  final String userName;
  final String? avatarUrl;
  final String? roleLabel;
  final VoidCallback onAvatarTap;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName => userName.trim().split(RegExp(r'\s+')).first;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.forestDark, AppColors.forestPanel],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    key: const Key('profile-avatar-button'),
                    onTap: onAvatarTap,
                    customBorder: const CircleBorder(),
                    child: UserAvatar(
                      name: userName,
                      avatarUrl: avatarUrl,
                      radius: 18,
                      fallbackColor: AppColors.mint.withValues(alpha: 0.18),
                      fallbackTextColor: AppColors.mint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (roleLabel != null)
                          Text(
                            roleLabel!.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.mint,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        Text(
                          'Agro Hub',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onSearchTap,
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                  NotificationBellButton(onTap: onNotificationsTap),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$_greeting, $_firstName!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's what's growing in your community today.",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textOnDarkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
