import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/user_avatar.dart';

/// The Marketplace tab's header — a compact dark brand bar matching every
/// other tab's header convention: the real profile avatar top-left, brand
/// name/tagline in the middle, and action icons top-right.
class MarketplaceHeroHeader extends StatelessWidget {
  const MarketplaceHeroHeader({
    super.key,
    required this.userName,
    this.avatarUrl,
    required this.openOfferCount,
    required this.onAvatarTap,
    required this.onMessagesTap,
    required this.onFavoritesTap,
  });

  final String userName;
  final String? avatarUrl;
  final int openOfferCount;
  final VoidCallback onAvatarTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onFavoritesTap;

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
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Agro Hub',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'MARKET',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.mint,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ],
                    ),
                    Text(
                      'Swap, sell & source locally',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavoritesTap,
                icon: const Icon(Icons.favorite_border, color: Colors.white),
                tooltip: 'Favorites',
              ),
              IconButton(
                onPressed: onMessagesTap,
                icon: Badge(
                  isLabelVisible: openOfferCount > 0,
                  label: Text('$openOfferCount'),
                  backgroundColor: AppColors.mint,
                  textColor: AppColors.forestDark,
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                  ),
                ),
                tooltip: 'Messages',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
