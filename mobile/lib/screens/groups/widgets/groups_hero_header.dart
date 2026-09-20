import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/notification_bell_button.dart';
import '../../../widgets/user_avatar.dart';

/// The Groups tab's green hero header — the bell opens the real
/// notification inbox, same as the other tabs' headers.
class GroupsHeroHeader extends StatelessWidget {
  const GroupsHeroHeader({
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
                    Text(
                      'COMMUNITY HUBS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mint,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              NotificationBellButton(onTap: onNotificationsTap),
            ],
          ),
        ),
      ),
    );
  }
}
