import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

class SkeletonLoader extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadiusGeometry? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoader({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppColors.border;
    final highlight = widget.highlightColor ?? const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius:
                widget.borderRadius ??
                BorderRadius.circular(AppDimens.radiusSm),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [
                base,
                highlight,
                base,
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool? shrinkWrap;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.itemHeight = 72,
    this.padding,
    this.physics,
    this.shrinkWrap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isUnbounded = constraints.maxHeight.isInfinite;
        return ListView.separated(
          padding: padding ?? const EdgeInsets.all(AppDimens.screenPadding),
          physics: isUnbounded
              ? const NeverScrollableScrollPhysics()
              : physics,
          shrinkWrap: shrinkWrap ?? isUnbounded,
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapMd),
          itemBuilder: (_, _) => SkeletonLoader(
            height: itemHeight,
            width: double.infinity,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        );
      },
    );
  }
}
