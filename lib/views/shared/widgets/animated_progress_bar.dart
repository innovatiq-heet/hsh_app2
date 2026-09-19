import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';

/// Rounded linear progress with a gradient fill and soft glow that eases
/// from its previous value to [value] (0..1).
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Gradient gradient;
  final Color trackColor;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.gradient = const LinearGradient(
      colors: [AppColors.cyan, AppColors.primaryLight, AppColors.indigo],
    ),
    this.trackColor = AppColors.surfaceMuted,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusPill);
    return Container(
      height: height,
      decoration: BoxDecoration(color: trackColor, borderRadius: radius),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: radius,
                boxShadow: AppColors.glow(AppColors.primaryLight, 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
