import 'dart:math' as math;
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

/// A modern, tactile, and theme-consistent pull-to-refresh widget.
///
/// Wraps any scrollable child (e.g. [ListView], [CustomScrollView],
/// [SingleChildScrollView]) and displays a floating, glassmorphic pill badge
/// with polished 4-phase animations:
/// 1. **Pulling**: Dynamic progress ring and rotating arrow that track pull distance.
/// 2. **Armed**: Subtle haptic feedback and snap bounce when the threshold is reached.
/// 3. **Refreshing**: Continuous dual-tone spinning ring with "Updating..." status.
/// 4. **Completed**: Morph into success checkmark with "Up to date" settle before retiring.
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
    this.triggerOffset = 85.0,
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
  late final AnimationController _completeController;

  late Animation<double> _settleAnimation;

  @override
  void initState() {
    super.initState();

    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        setState(() {
          _dragOffset = _settleAnimation.value;
        });
      });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _completeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _settleController.dispose();
    _spinController.dispose();
    _completeController.dispose();
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
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
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

    // While refreshing, ignore pull gestures so duplicate refreshes cannot happen.
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
        // Pulling down past top edge
        final double delta = -notification.overscroll;
        _handlePullDelta(delta);
      }
    } else if (notification is ScrollUpdateNotification) {
      // For bouncing physics (iOS or custom scroll physics) where pixels go negative
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
    // Rubber-band dampening resistance: resistance increases the further pulled
    final double resistance = 1.0 - (_dragOffset / (widget.triggerOffset * 2.5)).clamp(0.25, 0.85);
    final double effectiveDelta = rawDelta * resistance;
    _updateDragOffset(_dragOffset + effectiveDelta);
  }

  void _updateDragOffset(double newOffset) {
    final double maxOffset = widget.triggerOffset * 1.6;
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

    // Trigger tactile haptic pulse on entering the armed state
    if (oldPhase != RefreshPhase.armed && nextPhase == RefreshPhase.armed) {
      HapticFeedback.lightImpact();
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

    // Spring to rest at trigger position while loading
    _settleController.stop();
    _settleAnimation = Tween<double>(
      begin: _dragOffset,
      end: widget.triggerOffset,
    ).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutBack),
    );
    _settleController.forward(from: 0.0);

    _spinController.repeat();

    try {
      await widget.onRefresh();
    } catch (_) {
      // Errors handled by screens / controllers
    } finally {
      if (mounted) {
        _spinController.stop();

        // Transition to completed phase
        setState(() {
          _phase = RefreshPhase.completed;
        });

        _completeController.forward(from: 0.0);
        HapticFeedback.selectionClick();

        // Brief delay (420ms) so user can see the "Up to date" success feedback
        await Future<void>.delayed(const Duration(milliseconds: 420));

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
    final double defaultTop = mediaQuery.padding.top + 10;
    final double effectiveTop = widget.topOffset ?? defaultTop;

    // Progress from 0.0 to 1.0 (clamped)
    final double pullProgress =
        (_dragOffset / widget.triggerOffset).clamp(0.0, 1.0);

    // Indicator translation: floats down gracefully with dampening
    final double indicatorY = effectiveTop + (_dragOffset * 0.45);

    // Opacity fades in as pulled
    final double opacity = (_dragOffset / (widget.triggerOffset * 0.4)).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
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
                    child: _RefreshBadge(
                      phase: _phase,
                      pullProgress: pullProgress,
                      spinAnimation: _spinController,
                      completeAnimation: _completeController,
                      backgroundColor: widget.backgroundColor ?? AppColors.surface,
                      accentColor: widget.accentColor ?? AppColors.primary,
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
        return 0.7;
      case RefreshPhase.pulling:
        return 0.75 + (0.25 * pullProgress);
      case RefreshPhase.armed:
        return 1.05;
      case RefreshPhase.refreshing:
        return 1.0;
      case RefreshPhase.completed:
        return 1.02;
    }
  }
}

/// Floating modern pill badge with status text and animated visual icon.
class _RefreshBadge extends StatelessWidget {
  final RefreshPhase phase;
  final double pullProgress;
  final Animation<double> spinAnimation;
  final Animation<double> completeAnimation;
  final Color backgroundColor;
  final Color accentColor;
  final bool compact;

  const _RefreshBadge({
    required this.phase,
    required this.pullProgress,
    required this.spinAnimation,
    required this.completeAnimation,
    required this.backgroundColor,
    required this.accentColor,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.all(AppDimens.gapSm + 2)
          : const EdgeInsets.symmetric(
              horizontal: AppDimens.gapLg,
              vertical: AppDimens.gapSm + 1,
            ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(
          color: phase == RefreshPhase.completed
              ? AppColors.successGreen.withValues(alpha: 0.35)
              : phase == RefreshPhase.armed
                  ? accentColor.withValues(alpha: 0.35)
                  : AppColors.border.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: (phase == RefreshPhase.completed
                    ? AppColors.successGreen
                    : accentColor)
                .withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIconIndicator(),
          if (!compact) ...[
            const SizedBox(width: AppDimens.gapSm + 2),
            _buildStatusText(),
          ],
        ],
      ),
    );
  }

  Widget _buildIconIndicator() {
    const double size = 20;

    switch (phase) {
      case RefreshPhase.idle:
      case RefreshPhase.pulling:
      case RefreshPhase.armed:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ArcProgressPainter(
              progress: pullProgress,
              trackColor: AppColors.surfaceMuted,
              activeColor: phase == RefreshPhase.armed
                  ? accentColor
                  : accentColor.withValues(alpha: 0.75 + (pullProgress * 0.25)),
              strokeWidth: 2.2,
            ),
            child: Center(
              child: Transform.rotate(
                angle: pullProgress * math.pi * 1.5,
                child: Icon(
                  phase == RefreshPhase.armed
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 13,
                  color: phase == RefreshPhase.armed
                      ? accentColor
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );

      case RefreshPhase.refreshing:
        return RotationTransition(
          turns: spinAnimation,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _SpinningRingPainter(
                primaryColor: accentColor,
                secondaryColor: AppColors.secondary,
                strokeWidth: 2.3,
              ),
            ),
          ),
        );

      case RefreshPhase.completed:
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: completeAnimation,
            curve: Curves.elasticOut,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: size,
            color: AppColors.successGreen,
          ),
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
        label = 'Pull to refresh';
        textColor = AppColors.textSecondary;
        fontWeight = FontWeight.w600;
        break;
      case RefreshPhase.armed:
        label = 'Release to refresh';
        textColor = accentColor;
        fontWeight = FontWeight.w700;
        break;
      case RefreshPhase.refreshing:
        label = 'Updating...';
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
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.15),
              end: Offset.zero,
            ).animate(animation),
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

/// Custom painter for the circular progress arc during pull-down.
class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color activeColor;
  final double strokeWidth;

  _ArcProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.activeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    if (progress > 0.01) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Custom painter for the continuous gradient rotating ring during refresh.
class _SpinningRingPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double strokeWidth;

  _SpinningRingPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepGradient = SweepGradient(
      colors: [
        primaryColor.withValues(alpha: 0.0),
        primaryColor.withValues(alpha: 0.4),
        secondaryColor,
        primaryColor,
      ],
      stops: const [0.0, 0.4, 0.75, 1.0],
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    const startAngle = 0.0;
    const sweepAngle = math.pi * 1.65;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_SpinningRingPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
