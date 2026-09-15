import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/user_avatar.dart';

/// The Events tab's green hero header. The calendar icon opens the real
/// month calendar view (see EventsCalendarScreen); notifications has no
/// backend yet, so that icon is still wired as a "coming soon" tap.
class EventsHeroHeader extends StatelessWidget {
  const EventsHeroHeader({
    super.key,
    required this.userName,
    this.avatarUrl,
    required this.onAvatarTap,
    required this.onCalendarTap,
    required this.onNotificationsTap,
  });

  final String userName;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onNotificationsTap;

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
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
          child: Row(
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
                    Text(
                      'Agro Hub',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.mint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Community & Events',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: AppColors.mint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCalendarTap,
                icon: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: onNotificationsTap,
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
