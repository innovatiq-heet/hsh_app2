import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// A high-fidelity, standalone animated illustration for offline states.
/// Features:
/// - Concentric expanding radar rings simulating searching for a signal
/// - Smooth floating/hovering central signal hub
/// - Glowing disconnected alert badge with subtle pulse
/// - Ambient floating signal particles
class NoInternetAnimation extends StatefulWidget {
  final double size;

  const NoInternetAnimation({
    super.key,
    this.size = 220,
  });

  @override
  State<NoInternetAnimation> createState() => _NoInternetAnimationState();
}

class _NoInternetAnimationState extends State<NoInternetAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _hoverController;
  late final AnimationController _badgePulseController;

  @override
  void initState() {
    super.initState();

    // Radar ripple waves
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Gentle hover effect
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Alert badge pulse
    _badgePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hoverController.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Concentric pulsing radar waves
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return CustomPaint(
                size: Size(s, s),
                painter: _RadarRipplePainter(
                  progress: _pulseController.value,
                  color: AppColors.primary,
                ),
              );
            },
          ),

          // 2. Gentle hovering central container
          AnimatedBuilder(
            animation: _hoverController,
            builder: (context, child) {
              final dy = math.sin(_hoverController.value * math.pi) * 6;
              return Transform.translate(
                offset: Offset(0, -dy),
                child: child,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Outer subtle glow halo
                Container(
                  width: s * 0.58,
                  height: s * 0.58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),

                // Main circular disc
                Container(
                  width: s * 0.54,
                  height: s * 0.54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        AppColors.mainBackground,
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.35),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background soft icon wash
                        Icon(
                          Icons.wifi_off_rounded,
                          size: s * 0.28,
                          color: AppColors.primary.withValues(alpha: 0.95),
                        ),
                      ],
                    ),
                  ),
                ),

                // Disconnected status badge with pulsing glow
                Positioned(
                  right: s * 0.06,
                  bottom: s * 0.06,
                  child: AnimatedBuilder(
                    animation: _badgePulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_badgePulseController.value * 0.12);
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.cancelledRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cancelledRed.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

                // Floating ambient particles
                ..._buildParticles(s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildParticles(double s) {
    return [
      _AmbientParticle(
        parentAnimation: _pulseController,
        baseOffset: Offset(-s * 0.32, -s * 0.20),
        size: 7,
        color: AppColors.secondary,
        delayFactor: 0.1,
      ),
      _AmbientParticle(
        parentAnimation: _pulseController,
        baseOffset: Offset(s * 0.30, -s * 0.18),
        size: 9,
        color: AppColors.primaryLight,
        delayFactor: 0.35,
      ),
      _AmbientParticle(
        parentAnimation: _pulseController,
        baseOffset: Offset(-s * 0.24, s * 0.24),
        size: 6,
        color: AppColors.warningOrange,
        delayFactor: 0.65,
      ),
    ];
  }
}

/// Custom painter rendering multi-layered expanding radar waves.
class _RadarRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarRipplePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw 3 waves with staggered phases
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = (size.width * 0.28) + (maxRadius - (size.width * 0.28)) * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.32;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 - (waveProgress * 1.2);

      canvas.drawCircle(center, radius, paint);

      // Subtle filled inner wash for the outermost expanding wave
      if (i == 0) {
        final fillPaint = Paint()
          ..color = color.withValues(alpha: opacity * 0.08)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Micro ambient particle drifting gracefully around the center.
class _AmbientParticle extends StatelessWidget {
  final Animation<double> parentAnimation;
  final Offset baseOffset;
  final double size;
  final Color color;
  final double delayFactor;

  const _AmbientParticle({
    required this.parentAnimation,
    required this.baseOffset,
    required this.size,
    required this.color,
    required this.delayFactor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: parentAnimation,
      builder: (context, _) {
        final t = (parentAnimation.value + delayFactor) % 1.0;
        final wobbleY = math.sin(t * 2 * math.pi) * 8;
        final opacity = 0.3 + 0.6 * math.sin(t * math.pi);

        return Transform.translate(
          offset: Offset(baseOffset.dx, baseOffset.dy + wobbleY),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: opacity * 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
