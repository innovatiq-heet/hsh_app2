import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';

class SkeletonLoader extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadiusGeometry? borderRadius;

  const SkeletonLoader({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius,
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
              colors: const [
                AppColors.border,
                Color(0xFFF1F5F9),
                AppColors.border,
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

  const SkeletonList({super.key, this.count = 5, this.itemHeight = 72});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapMd),
      itemBuilder: (_, _) => SkeletonLoader(
        height: itemHeight,
        width: double.infinity,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
    );
  }
}
