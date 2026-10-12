import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Read-only 5-star display for an average rating (e.g. 3.6 renders 3 full
/// stars, one partially-lit-looking-but-actually-just-rounded star — this
/// app has no half-star asset, so it rounds to the nearest whole star).
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = AppColors.mint,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= filled ? Icons.star : Icons.star_border,
            size: size,
            color: color,
          ),
      ],
    );
  }
}

/// Tappable 1-5 star picker for the "write a review" sheet.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 36,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            key: Key('star-rating-input-$i'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= rating ? Icons.star : Icons.star_border,
              size: size,
              color: AppColors.mint,
            ),
          ),
      ],
    );
  }
}
