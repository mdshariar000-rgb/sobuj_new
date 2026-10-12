import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'image_decode.dart';

/// A real avatar photo when the user has uploaded one, falling back to an
/// initial-letter circle otherwise — never a fabricated stock photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 18,
    this.fallbackColor = AppColors.surfaceMuted,
    this.fallbackTextColor = AppColors.primary,
  });

  final String name;
  final String? avatarUrl;
  final double radius;

  /// Background of the initial-letter fallback when there's no real photo —
  /// e.g. listing cards vary this per-seller for visual distinction.
  final Color fallbackColor;

  /// Text color of the initial-letter fallback — the default reads on the
  /// light `surfaceMuted` background most call sites use; the dark hero
  /// headers (Home/Events tabs) pass mint instead so it stays legible on
  /// their forest-green background.
  final Color fallbackTextColor;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceMuted,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: radius * 2,
            height: radius * 2,
            memCacheWidth: decodeWidthFor(context, radius * 2),
            fit: BoxFit.cover,
            placeholder: (context, _) => const SizedBox.shrink(),
            errorWidget: (context, _, _) => _InitialCircle(
              name: name,
              radius: radius,
              color: fallbackColor,
              textColor: fallbackTextColor,
            ),
          ),
        ),
      );
    }

    return _InitialCircle(
      name: name,
      radius: radius,
      color: fallbackColor,
      textColor: fallbackTextColor,
    );
  }
}

class _InitialCircle extends StatelessWidget {
  const _InitialCircle({
    required this.name,
    required this.radius,
    required this.color,
    required this.textColor,
  });

  final String name;
  final double radius;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.65,
        ),
      ),
    );
  }
}
