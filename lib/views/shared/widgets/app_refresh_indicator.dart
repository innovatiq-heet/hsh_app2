import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';

/// The 4 distinct visual & interaction phases of pull-to-refresh.
enum RefreshPhase {
  /// Resting state, indicator is hidden.
  idle,

  /// User is pulling down, but has not reached the refresh threshold.
  pulling,

  /// User has pulled beyond the threshold; releasing now will trigger refresh.
  armed,

  /// Async refresh task is in progress; indicator is locked and animating.
  refreshing,

  /// Refresh task has completed; brief success checkmark before retiring.
  completed,
}

/// A custom, high-fidelity pull-to-refresh widget with signature fluid animations:
/// 1. **Liquid Elastic Tether**: Stretchy liquid teardrop extending from the top edge.
/// 2. **Orbital Dual-Ring Gyroscope**: Counter-rotating gradient rings with glowing satellites.
/// 3. **Frosted Glassmorphic Badge**: Translucent backdrop blur with dynamic ambient glow.
/// 4. **Celebration Sparkle Burst**: Radiating micro-particle burst upon completion.
class AppRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double triggerOffset;
  final double? topOffset;
  final Color? backgroundColor;
  final Color? accentColor;
  final bool compact;
  final ScrollNotificationPredicate notificationPredicate;

  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerOffset = 90.0,
    this.topOffset,
    this.backgroundColor,
    this.accentColor,
    this.compact = false,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  @override
  State<AppRefreshIndicator> createState() => AppRefreshIndicatorState();
}

class AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with TickerProviderStateMixin {
  RefreshPhase _phase = RefreshPhase.idle;
  double _dragOffset = 0.0;
  bool _isRefreshing = false;

  late final AnimationController _settleController;
  late final AnimationController _spinController;
  late final AnimationController _hoverController;
  late final AnimationController _completeController;
  late final AnimationController _burstController;

  late Animation<double> _settleAnimation;

  @override
  void initState() {
    super.initState();

    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..addListener(() {
        setState(() {
          _dragOffset = _settleAnimation.value;
        });
      });

    // Continuous orbital gyroscope spin
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Subtle gentle floating hover while refreshing
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Success checkmark scale
    _completeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Radiant sparkle confetti burst
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _settleController.dispose();
    _spinController.dispose();
    _hoverController.dispose();
    _completeController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  /// Programmatically trigger the refresh animation and async callback.
  Future<void> show() async {
    if (_isRefreshing) return;
    _animateToRefreshingPosition();
  }

  void _animateToRefreshingPosition() {
    _settleController.stop();
    _settleAnimation = Tween<double>(
      begin: _dragOffset,
      end: widget.triggerOffset,
    ).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutBack),
    );

    _settleController.forward(from: 0.0).then((_) {
      _startRefresh();
    });
  }

  void _animateToRest() {
    _settleController.stop();
    _settleAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeInOutCubic),
    );

    _settleController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _phase = RefreshPhase.idle;
          _dragOffset = 0.0;
        });
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) {
      return false;
    }

    if (_isRefreshing) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      if (_phase == RefreshPhase.idle &&
          notification.metrics.extentBefore == 0) {
        _settleController.stop();
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        final double delta = -notification.overscroll;
        _handlePullDelta(delta);
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        final double target = -notification.metrics.pixels;
        _updateDragOffset(target);
      } else if (notification.dragDetails != null &&
          notification.metrics.extentBefore == 0 &&
          notification.dragDetails!.delta.dy > 0) {
        _handlePullDelta(notification.dragDetails!.delta.dy);
      }
    } else if (notification is ScrollEndNotification ||
        notification is UserScrollNotification) {
      if (_dragOffset > 0 && !_isRefreshing) {
        _handleDragEnd();
      }
    }

    return false;
  }

  void _handlePullDelta(double rawDelta) {
    final double resistance =
        1.0 - (_dragOffset / (widget.triggerOffset * 2.8)).clamp(0.20, 0.88);
    final double effectiveDelta = rawDelta * resistance;
    _updateDragOffset(_dragOffset + effectiveDelta);
  }

  void _updateDragOffset(double newOffset) {
    final double maxOffset = widget.triggerOffset * 1.7;
    final double clamped = newOffset.clamp(0.0, maxOffset);

    final RefreshPhase oldPhase = _phase;
    final RefreshPhase nextPhase;

    if (clamped <= 0.0) {
      nextPhase = RefreshPhase.idle;
    } else if (clamped >= widget.triggerOffset) {
      nextPhase = RefreshPhase.armed;
    } else {
      nextPhase = RefreshPhase.pulling;
    }

    // Crisp tactile haptic impact on reaching trigger point
    if (oldPhase != RefreshPhase.armed && nextPhase == RefreshPhase.armed) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _dragOffset = clamped;
      _phase = nextPhase;
    });
  }

  void _handleDragEnd() {
    if (_phase == RefreshPhase.armed) {
      _startRefresh();
    } else {
      _animateToRest();
    }
  }

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _phase = RefreshPhase.refreshing;
    });

    _settleController.stop();
    _settleAnimation = Tween<double>(
      begin: _dragOffset,
      end: widget.triggerOffset,
    ).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutBack),
    );
    _settleController.forward(from: 0.0);

    _spinController.repeat();
    _hoverController.repeat(reverse: true);

    try {
      await widget.onRefresh();
    } catch (_) {
      // Handled by controller/view
    } finally {
      if (mounted) {
        _spinController.stop();
        _hoverController.stop();

        setState(() {
          _phase = RefreshPhase.completed;
        });

        _completeController.forward(from: 0.0);
        _burstController.forward(from: 0.0);
        HapticFeedback.lightImpact();

        // Brief delay for the celebratory checkmark and particle burst
        await Future<void>.delayed(const Duration(milliseconds: 520));

        if (mounted) {
          _animateToRest();
          _isRefreshing = false;
        }
      } else {
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double defaultTop = mediaQuery.padding.top + 8;
    final double effectiveTop = widget.topOffset ?? defaultTop;

    final double pullProgress =
        (_dragOffset / widget.triggerOffset).clamp(0.0, 1.0);

    // Indicator floats down with elastic dampening
    double indicatorY = effectiveTop + (_dragOffset * 0.44);

    // Subtle gentle float hover while refreshing
    if (_phase == RefreshPhase.refreshing) {
      final hoverDy = math.sin(_hoverController.value * math.pi * 2) * 2.5;
      indicatorY += hoverDy;
    }

    final double opacity =
        (_dragOffset / (widget.triggerOffset * 0.35)).clamp(0.0, 1.0);

    final accentColor = widget.accentColor ?? AppColors.primary;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,

          // 1. Elastic Liquid Tether extending from the top edge
          if (_phase == RefreshPhase.pulling && _dragOffset > 15)
            Positioned(
              top: effectiveTop - 4,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: CustomPaint(
                  size: Size(120, (_dragOffset * 0.45) + 12),
                  painter: _LiquidTetherPainter(
                    progress: pullProgress,
                    color: accentColor.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),

          // 2. Floating Glassmorphic Gyroscope Capsule
          if (_phase != RefreshPhase.idle || _dragOffset > 0)
            Positioned(
              top: indicatorY,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: _getScaleForPhase(pullProgress),
                    child: _FancyRefreshBadge(
                      phase: _phase,
                      pullProgress: pullProgress,
                      spinAnimation: _spinController,
                      completeAnimation: _completeController,
                      burstAnimation: _burstController,
                      backgroundColor:
                          widget.backgroundColor ?? Colors.white.withValues(alpha: 0.92),
                      accentColor: accentColor,
                      compact: widget.compact,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _getScaleForPhase(double pullProgress) {
    switch (_phase) {
      case RefreshPhase.idle:
        return 0.65;
      case RefreshPhase.pulling:
        return 0.70 + (0.30 * pullProgress);
      case RefreshPhase.armed:
        return 1.06;
      case RefreshPhase.refreshing:
        return 1.0;
      case RefreshPhase.completed:
        return 1.04;
    }
  }
}

/// Floating glassmorphic capsule with glowing orbital gyroscope and status text.
class _FancyRefreshBadge extends StatelessWidget {
  final RefreshPhase phase;
  final double pullProgress;
  final Animation<double> spinAnimation;
  final Animation<double> completeAnimation;
  final Animation<double> burstAnimation;
  final Color backgroundColor;
  final Color accentColor;
  final bool compact;

  const _FancyRefreshBadge({
    required this.phase,
    required this.pullProgress,
    required this.spinAnimation,
    required this.completeAnimation,
    required this.burstAnimation,
    required this.backgroundColor,
    required this.accentColor,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isArmed = phase == RefreshPhase.armed;
    final isCompleted = phase == RefreshPhase.completed;

    final glowColor = isCompleted
        ? AppColors.successGreen
        : (isArmed ? AppColors.secondary : accentColor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: compact
              ? const EdgeInsets.all(AppDimens.gapSm + 3)
              : const EdgeInsets.symmetric(
                  horizontal: AppDimens.gapLg + 2,
                  vertical: AppDimens.gapSm + 2,
                ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: Border.all(
              color: isCompleted
                  ? AppColors.successGreen.withValues(alpha: 0.45)
                  : (isArmed
                      ? accentColor.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.85)),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: isArmed ? 0.28 : 0.14),
                blurRadius: isArmed ? 20 : 12,
                offset: const Offset(0, 5),
                spreadRadius: isArmed ? 2 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildGyroscope(),
              if (!compact) ...[
                const SizedBox(width: AppDimens.gapSm + 4),
                _buildStatusText(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGyroscope() {
    const double size = 26;

    switch (phase) {
      case RefreshPhase.idle:
      case RefreshPhase.pulling:
      case RefreshPhase.armed:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _PullGyroscopePainter(
              progress: pullProgress,
              isArmed: phase == RefreshPhase.armed,
              primaryColor: accentColor,
              secondaryColor: AppColors.secondary,
            ),
            child: Center(
              child: Transform.rotate(
                angle: pullProgress * math.pi * 1.5,
                child: Icon(
                  phase == RefreshPhase.armed
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: phase == RefreshPhase.armed
                      ? accentColor
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );

      case RefreshPhase.refreshing:
        return AnimatedBuilder(
          animation: spinAnimation,
          builder: (context, _) {
            return SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _OrbitalGyroscopePainter(
                  rotation: spinAnimation.value,
                  primaryColor: accentColor,
                  secondaryColor: AppColors.secondary,
                ),
              ),
            );
          },
        );

      case RefreshPhase.completed:
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Particle burst sparkles radiating outward
            AnimatedBuilder(
              animation: burstAnimation,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(size, size),
                  painter: _SparkleBurstPainter(
                    progress: burstAnimation.value,
                    color: AppColors.successGreen,
                  ),
                );
              },
            ),

            // Pop-in checkmark
            ScaleTransition(
              scale: CurvedAnimation(
                parent: completeAnimation,
                curve: Curves.elasticOut,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 22,
                color: AppColors.successGreen,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildStatusText() {
    final String label;
    final Color textColor;
    final FontWeight fontWeight;

    switch (phase) {
      case RefreshPhase.idle:
      case RefreshPhase.pulling:
        label = 'Pull to sync';
        textColor = AppColors.textSecondary;
        fontWeight = FontWeight.w600;
        break;
      case RefreshPhase.armed:
        label = 'Release to refresh';
        textColor = accentColor;
        fontWeight = FontWeight.w700;
        break;
      case RefreshPhase.refreshing:
        label = 'Updating hostel data...';
        textColor = accentColor;
        fontWeight = FontWeight.w600;
        break;
      case RefreshPhase.completed:
        label = 'Up to date';
        textColor = AppColors.successGreen;
        fontWeight = FontWeight.w700;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 190),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.20),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
      child: Text(
        label,
        key: ValueKey<String>(label),
        style: AppTextStyles.caption.copyWith(
          color: textColor,
          fontWeight: fontWeight,
          fontSize: 12.5,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

/// Liquid tether drawn from the top edge as the user pulls.
class _LiquidTetherPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LiquidTetherPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.12) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final topWidth = (36.0 * (1.0 - progress * 0.4)).clamp(10.0, 40.0);
    final bottomY = size.height;

    path.moveTo(centerX - topWidth / 2, 0);
    path.quadraticBezierTo(
      centerX - (topWidth * 0.15),
      bottomY * 0.60,
      centerX,
      bottomY,
    );
    path.quadraticBezierTo(
      centerX + (topWidth * 0.15),
      bottomY * 0.60,
      centerX + topWidth / 2,
      0,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LiquidTetherPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Dual-arc gyroscope painter for pulling phase.
class _PullGyroscopePainter extends CustomPainter {
  final double progress;
  final bool isArmed;
  final Color primaryColor;
  final Color secondaryColor;

  _PullGyroscopePainter({
    required this.progress,
    required this.isArmed,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width - 2.5) / 2;
    final innerRadius = outerRadius - 3.8;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, outerRadius, trackPaint);

    // Primary outer arc
    if (progress > 0.02) {
      final outerPaint = Paint()
        ..color = isArmed ? secondaryColor : primaryColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
        outerPaint,
      );
    }

    // Inner subtle counter-arc when past halfway
    if (progress > 0.45) {
      final innerProgress = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
      final innerPaint = Paint()
        ..color = secondaryColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6;

      const startAngle = math.pi / 2;
      final sweepAngle = -2 * math.pi * innerProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        sweepAngle,
        false,
        innerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PullGyroscopePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isArmed != isArmed;
  }
}

/// High-tech orbital gyroscope: dual counter-rotating gradient rings with orbiting satellites.
class _OrbitalGyroscopePainter extends CustomPainter {
  final double rotation;
  final Color primaryColor;
  final Color secondaryColor;

  _OrbitalGyroscopePainter({
    required this.rotation,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width - 2.5) / 2;
    final innerRadius = outerRadius - 4.2;

    // 1. Outer Ring (Rotates Clockwise with Gradient Sweep)
    final outerAngle = rotation * 2 * math.pi;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);

    final outerGradient = SweepGradient(
      startAngle: 0.0,
      endAngle: math.pi * 2,
      colors: [
        primaryColor.withValues(alpha: 0.0),
        primaryColor.withValues(alpha: 0.35),
        secondaryColor,
        primaryColor,
      ],
      stops: const [0.0, 0.35, 0.75, 1.0],
      transform: GradientRotation(outerAngle),
    );

    final outerPaint = Paint()
      ..shader = outerGradient.createShader(outerRect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    canvas.drawArc(outerRect, outerAngle, math.pi * 1.65, false, outerPaint);

    // 2. Inner Ring (Counter-Rotates with Gradient Sweep)
    final innerAngle = -rotation * 2.5 * math.pi;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    final innerGradient = SweepGradient(
      startAngle: 0.0,
      endAngle: math.pi * 2,
      colors: [
        secondaryColor.withValues(alpha: 0.0),
        secondaryColor.withValues(alpha: 0.4),
        primaryColor,
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientRotation(innerAngle),
    );

    final innerPaint = Paint()
      ..shader = innerGradient.createShader(innerRect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;

    canvas.drawArc(innerRect, innerAngle, math.pi * 1.4, false, innerPaint);

    // 3. Orbiting Satellite Particles
    final satAngle = outerAngle + (math.pi * 1.65);
    final satX = center.dx + outerRadius * math.cos(satAngle);
    final satY = center.dy + outerRadius * math.sin(satAngle);

    final satPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(satX, satY), 2.0, satPaint);

    final satGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(satX, satY), 3.5, satGlowPaint);
  }

  @override
  bool shouldRepaint(_OrbitalGyroscopePainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

/// Celebratory particle sparkles bursting radially upon refresh completion.
class _SparkleBurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SparkleBurstPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    const particleCount = 8;
    final currentDistance = 14.0 + (progress * 18.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final particleRadius = (1.0 - progress * 0.45) * 2.5;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i * 2 * math.pi) / particleCount;
      final x = center.dx + currentDistance * math.cos(angle);
      final y = center.dy + currentDistance * math.sin(angle);
      canvas.drawCircle(Offset(x, y), particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
