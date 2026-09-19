import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Circular completion ring with a sweep-gradient arc and rounded caps.
/// Animates from its previous value to [value] (0..1).
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final List<Color> colors;
  final Color trackColor;
  final Widget? center;
  final Duration duration;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 84,
    this.strokeWidth = 8,
    this.colors = const [AppColors.cyan, AppColors.primaryLight, AppColors.indigo],
    this.trackColor = const Color(0x2EFFFFFF),
    this.center,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(
            progress: v,
            strokeWidth: strokeWidth,
            colors: colors,
            trackColor: trackColor,
          ),
          child: child,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final List<Color> colors;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);

    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    if (progress <= 0) return;
    final sweep = math.pi * 2 * progress;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.max(sweep, 0.01),
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor;
}
