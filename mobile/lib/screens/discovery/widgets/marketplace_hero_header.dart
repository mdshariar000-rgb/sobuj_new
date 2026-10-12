import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// The Marketplace header shared by every marketplace screen: an optional
/// back arrow, the leaf logo, "Shobuj MARKETPLACE / Swap & Sell", and the
/// Favorites and Messages icons on the right.
class MarketplaceHeroHeader extends StatelessWidget {
  const MarketplaceHeroHeader({
    super.key,
    required this.openOfferCount,
    required this.onMessagesTap,
    required this.onFavoritesTap,
    this.onLogoTap,
    this.onBack,
  });

  final int openOfferCount;
  final VoidCallback onMessagesTap;
  final VoidCallback onFavoritesTap;

  /// The marketplace tab opens the user's profile from the logo.
  final VoidCallback? onLogoTap;

  /// Shows a back arrow when set — the pushed marketplace screens
  /// (Sell/Swap form) use it; the tab itself doesn't.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.forestDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 4, 10, 8, 12),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back',
                ),
              InkWell(
                key: const Key('profile-avatar-button'),
                onTap: onLogoTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco, color: AppColors.mint, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shobuj',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'MARKETPLACE',
                      style: TextStyle(
                        color: AppColors.mint,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      'Swap & Sell',
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
