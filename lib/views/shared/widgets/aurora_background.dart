import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Slowly drifting mesh/aurora gradient: a deep-slate → brand-blue wash with
/// three soft colour blobs orbiting on long, out-of-phase loops.
///
/// Painted in a single CustomPainter behind a RepaintBoundary, so the drift
/// repaints only this layer — content above it is not rebuilt.
class AuroraBackground extends StatefulWidget {
  final bool animate;

  const AuroraBackground({super.key, this.animate = true});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(_controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> t;

  _AuroraPainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = AppColors.heroGradient.createShader(rect),
    );

    final phase = t.value * math.pi * 2;
    final w = size.width;
    final h = size.height;

    _blob(
      canvas,
      Offset(w * (0.82 + 0.10 * math.sin(phase)), h * (0.12 + 0.10 * math.cos(phase))),
      w * 0.62,
      AppColors.indigo.withValues(alpha: 0.55),
    );
    _blob(
      canvas,
      Offset(w * (0.12 + 0.10 * math.cos(phase + 2)), h * (0.92 + 0.08 * math.sin(phase + 2))),
      w * 0.55,
      AppColors.cyan.withValues(alpha: 0.30),
    );
    _blob(
      canvas,
      Offset(w * (0.50 + 0.18 * math.sin(phase + 4)), h * (0.55 + 0.12 * math.cos(phase + 4))),
      w * 0.45,
      AppColors.violet.withValues(alpha: 0.28),
    );
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => false;
}
