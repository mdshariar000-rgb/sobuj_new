import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/notification_bell_button.dart';
import '../../../widgets/user_avatar.dart';

/// The Home tab's green hero header: avatar, the "Shobuj" name once, and
/// the notifications bell; then a time-of-day greeting with a line about
/// the user ("Balcony grower · Luton") — or the slogan when we know
/// neither. Logging out lives on the Profile page, not here, so it can't be
/// hit by accident next to the bell.
class HomeHeroHeader extends StatelessWidget {
  const HomeHeroHeader({
    super.key,
    required this.userName,
    this.avatarUrl,
    required this.onAvatarTap,
    required this.onNotificationsTap,
  });

  final String userName;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;
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
                    child: Text(
                      'Shobuj',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  NotificationBellButton(onTap: onNotificationsTap),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$_greeting, $_firstName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Grow. Share. Sustain.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textOnDarkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
