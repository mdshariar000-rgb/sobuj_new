import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Loading placeholders: grey shapes laid out like the content that's on
/// its way, with a soft shine sweeping across them — instead of a lone
/// spinner. Every page-level "loading" state in the app uses one of the
/// skeletons below; small inline spinners (buttons, "loading more") stay
/// as spinners.

const _base = Color(0xFFE3E8E4);
const _highlight = Color(0xFFF8FAF8);

/// Drives the shine for every [ShimmerBox] inside [child] — one shared
/// animation, so all the shapes on a screen sweep together.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShimmerScope(animation: _controller, child: widget.child);
}

class _ShimmerScope extends InheritedNotifier<Animation<double>> {
  const _ShimmerScope({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);

  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.notifier;
}

/// Slides the gradient's light band from left of the shape to right of it.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

/// One grey placeholder shape — shining when inside a [Shimmer].
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final progress = _ShimmerScope.of(context)?.value;
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: progress == null ? _base : null,
        gradient: progress == null
            ? null
            : LinearGradient(
                colors: const [_base, _highlight, _base],
                stops: const [0.3, 0.5, 0.7],
                transform: _SlideGradient(progress),
              ),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Lays skeleton content out without ever scrolling or overflowing, so it
/// can sit anywhere a spinner used to — in an Expanded, a Center, or a
/// sliver.
class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// Rows of cards with a square or round picture and a few text lines —
/// groups, events, chats, notifications, people, my listings.
class ShimmerCardList extends StatelessWidget {
  const ShimmerCardList({
    super.key,
    this.count = 6,
    this.thumbSize = 56,
    this.roundThumb = false,
    this.lines = 2,
  });

  final int count;
  final double thumbSize;
  final bool roundThumb;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return _Skeleton(
      key: const Key('shimmer-card-list'),
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ShimmerBox(
                  width: thumbSize,
                  height: thumbSize,
                  radius: 12,
                  circle: roundThumb,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.75 : 0.6,
                        child: const ShimmerBox(height: 14),
                      ),
                      for (var l = 1; l < lines; l++) ...[
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: l.isEven ? 0.35 : 0.5,
                          child: const ShimmerBox(height: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The two-column listing grid (Marketplace, Favorites, Home's "Picked for
/// you", search results).
class ShimmerListingGrid extends StatelessWidget {
  const ShimmerListingGrid({super.key, this.rows = 2, this.padding});

  final int rows;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget card() => Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.35,
            child: ShimmerBox(height: double.infinity, radius: 0),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 110, height: 12),
                SizedBox(height: 8),
                ShimmerBox(width: 60, height: 14),
                SizedBox(height: 10),
                ShimmerBox(width: 90, height: 10),
              ],
            ),
          ),
        ],
      ),
    );

    return _Skeleton(
      key: const Key('shimmer-listing-grid'),
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card()),
              const SizedBox(width: 12),
              Expanded(child: card()),
            ],
          ),
        ],
      ],
    );
  }
}

/// Post cards: author row, a few lines of text and a picture.
class ShimmerPostList extends StatelessWidget {
  const ShimmerPostList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return _Skeleton(
      key: const Key('shimmer-post-list'),
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    ShimmerBox(height: 36, circle: true),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 120, height: 12),
                        SizedBox(height: 6),
                        ShimmerBox(width: 70, height: 10),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const ShimmerBox(height: 12),
                const SizedBox(height: 8),
                const FractionallySizedBox(
                  widthFactor: 0.7,
                  child: ShimmerBox(height: 12),
                ),
                if (i.isEven) ...[
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 140, radius: 12),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Chat bubbles, alternating sides.
class ShimmerChat extends StatelessWidget {
  const ShimmerChat({super.key, this.count = 7});

  final int count;

  @override
  Widget build(BuildContext context) {
    const widths = [0.55, 0.4, 0.65, 0.35, 0.5, 0.6, 0.45];
    return _Skeleton(
      key: const Key('shimmer-chat'),
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < count; i++)
          Align(
            alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FractionallySizedBox(
                widthFactor: widths[i % widths.length],
                child: ShimmerBox(height: i % 3 == 0 ? 54 : 38, radius: 16),
              ),
            ),
          ),
      ],
    );
  }
}

/// A profile page: cover, avatar, name and stats, then a few rows.
class ShimmerProfile extends StatelessWidget {
  const ShimmerProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return _Skeleton(
      key: const Key('shimmer-profile'),
      padding: EdgeInsets.zero,
      children: [
        const ShimmerBox(height: 150, radius: 0),
        Transform.translate(
          offset: const Offset(0, -40),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 84, circle: true),
                SizedBox(height: 14),
                ShimmerBox(width: 160, height: 18),
                SizedBox(height: 10),
                ShimmerBox(width: 220, height: 12),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 44, radius: 22)),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBox(height: 44, radius: 22)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const ShimmerCardList(count: 3),
      ],
    );
  }
}
