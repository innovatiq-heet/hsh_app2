import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';

/// Sweeps a single highlight band across all of its descendant skeleton
/// shapes. One AnimationController drives the whole subtree (via a
/// ShaderMask), rather than one controller per placeholder box.
class ShimmerEffect extends StatefulWidget {
  final Widget child;

  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.6 + 3.2 * t, -0.3),
            end: Alignment(-0.6 + 3.2 * t, 0.3),
            colors: const [
              Color(0xFFE2E8F0),
              Color(0xFFF8FAFC),
              Color(0xFFE2E8F0),
            ],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Plain rounded placeholder shape; the shimmer comes from an enclosing
/// [ShimmerEffect].
class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = AppDimens.radiusLg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Generic list placeholder for screens with an app bar.
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const SkeletonList({super.key, this.count = 5, this.itemHeight = 84});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapMd),
        itemBuilder: (_, _) =>
            SkeletonBox(height: itemHeight, width: double.infinity),
      ),
    );
  }
}

/// Placeholder shaped like a hero-header screen: header block, a row of
/// tiles, then cards — so the layout doesn't jump when content arrives.
class HeroSkeleton extends StatelessWidget {
  const HeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const SkeletonBox(height: 250, radius: AppDimens.radiusXl + 4),
          Padding(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 18, width: 140, radius: 6),
                const SizedBox(height: AppDimens.gapLg),
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: AppDimens.gapMd),
                      const Expanded(child: SkeletonBox(height: 96)),
                    ],
                  ],
                ),
                const SizedBox(height: AppDimens.gapXl),
                for (int i = 0; i < 3; i++) ...[
                  const SkeletonBox(height: 96, width: double.infinity),
                  const SizedBox(height: AppDimens.gapMd),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
