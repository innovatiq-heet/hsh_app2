import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/enums/attendance_type.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../attendance/attendance_event_style.dart';

/// An iOS 17 NameDrop & Proximity Sharing celebratory overlay.
///
/// Features:
/// - iOS 17 rhythmic magnetic haptic vibration pulse sequence
/// - Harmonic fluid liquid light wave dropping and rippling from the top notch/island
/// - Concentric caustic wave rings & floating radiant stardust motes
/// - Deep luxury frosted glass attendance confirmation card
/// - Palette and typography strictly harmonized with APP_THEME_AND_COLORS.md
/// - Dynamic AttendanceEventStyle integration (adapting to Aarti, Morning, Lunch, Dinner, Night, Sabha)
/// - Interactive gestures (drag down to dismiss, tactile animated Done button)
class NamedropAttendanceOverlay extends StatefulWidget {
  final String title;
  final String sessionName;
  final String? subtitle;
  final String? studentName;
  final String? roomNo;
  final AttendanceType? eventType;
  final AttendanceEventStyle? eventStyle;
  final VoidCallback? onDismiss;

  const NamedropAttendanceOverlay({
    super.key,
    this.title = 'Attendance Marked!',
    this.sessionName = 'Session',
    this.subtitle,
    this.studentName,
    this.roomNo,
    this.eventType,
    this.eventStyle,
    this.onDismiss,
  });

  /// Convenient helper to display the NameDrop animation modal over any screen.
  static Future<void> show(
    BuildContext context, {
    String title = 'Attendance Marked!',
    String sessionName = 'Today\'s Session',
    String? subtitle,
    String? studentName,
    String? roomNo,
    AttendanceType? eventType,
    AttendanceEventStyle? eventStyle,
    VoidCallback? onDismiss,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent, // Handled internally with custom blur & vignette
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return NamedropAttendanceOverlay(
          title: title,
          sessionName: sessionName,
          subtitle: subtitle,
          studentName: studentName,
          roomNo: roomNo,
          eventType: eventType,
          eventStyle: eventStyle,
          onDismiss: onDismiss,
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  @override
  State<NamedropAttendanceOverlay> createState() =>
      _NamedropAttendanceOverlayState();
}

class _NamedropAttendanceOverlayState extends State<NamedropAttendanceOverlay>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _waveController;
  late AnimationController _cardController;
  late AnimationController _badgeController;
  late AnimationController _ambientController;
  late AnimationController _shimmerController;

  // Curves
  late Animation<double> _fluidStretch;
  late Animation<double> _waveGlow;
  late Animation<double> _cardSlide;
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;
  late Animation<double> _badgeScale;
  late Animation<double> _badgeHalo;

  // Stardust light particles
  final List<_NameDropStardust> _particles = [];
  final List<Timer> _hapticTimers = [];

  // Resolved event style
  late AttendanceEventStyle _resolvedStyle;

  // Drag down dismissal physics
  double _dragOffsetY = 0.0;
  bool _isDismissing = false;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();

    // 1. Resolve event style from explicit type, passed style, or smart name parsing
    _resolveStyle();

    // 2. Liquid wave expansion from top notch
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fluidStretch = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOutCubic,
    );

    _waveGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // 3. Spring card entrance from top under the wave
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _cardSlide = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutBack,
      ),
    );

    _cardScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutBack,
      ),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.08, 0.65, curve: Curves.easeOut),
      ),
    );

    // 4. Punchy checkmark emblem stamp
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _badgeScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: Curves.elasticOut,
      ),
    );

    _badgeHalo = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut),
      ),
    );

    // 5. Continuous ambient breathing & caustics
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 6. Subtle light shimmer across header highlight
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // 7. Seed stardust particles radiating from top notch
    final random = math.Random(108);
    for (int i = 0; i < 42; i++) {
      _particles.add(
        _NameDropStardust(
          angle: (random.nextDouble() * math.pi * 0.94) + (math.pi * 0.03), // downward arc
          speed: 140 + random.nextDouble() * 280,
          length: 10 + random.nextDouble() * 26,
          strokeWidth: 1.0 + random.nextDouble() * 2.4,
          alpha: 0.35 + random.nextDouble() * 0.65,
          colorIndex: i % 3,
        ),
      );
    }

    // 8. Kick off the orchestrated sequence
    _startOrchestratedSequence();
  }

  void _resolveStyle() {
    if (widget.eventStyle != null) {
      _resolvedStyle = widget.eventStyle!;
    } else if (widget.eventType != null) {
      _resolvedStyle = AttendanceEventStyle.of(widget.eventType!);
    } else {
      _resolvedStyle = AttendanceEventStyle.tryResolve(widget.sessionName) ??
          AttendanceEventStyle.of(AttendanceEventStyle.defaultEventForNow());
    }
  }

  /// iOS 17 NameDrop Rhythmic Vibration Sequence:
  /// Simulates device proximity magnetic attraction (escalating tick train),
  /// liquid wave apex burst (heavy impact), card touchdown (medium impact),
  /// and verified checkmark confirmation double-pulse (light impact + tick).
  void _startOrchestratedSequence() {
    // Stage 1: Initial proximity touch
    HapticFeedback.lightImpact();

    // Start wave animation
    _waveController.forward();

    // Stage 2: Rapidly accelerating magnetic pulse sequence (iOS wave feel)
    final pulseDelays = [70, 130, 185, 230, 270, 305, 335];
    for (final ms in pulseDelays) {
      _hapticTimers.add(
        Timer(Duration(milliseconds: ms), () {
          HapticFeedback.selectionClick();
        }),
      );
    }

    // Stage 3: Liquid Wave Apex Shockwave (t=360ms)
    _hapticTimers.add(
      Timer(const Duration(milliseconds: 360), () {
        HapticFeedback.heavyImpact();
        if (mounted) {
          _cardController.forward();
        }
      }),
    );

    // Stage 4: Card touchdown spring bounce (t=520ms)
    _hapticTimers.add(
      Timer(const Duration(milliseconds: 520), () {
        HapticFeedback.mediumImpact();
        if (mounted) {
          _badgeController.forward();
        }
      }),
    );

    // Stage 5: iOS Attendance Verified checkmark affirmation double-tap (t=680ms, 760ms)
    _hapticTimers.add(
      Timer(const Duration(milliseconds: 680), () {
        HapticFeedback.lightImpact();
      }),
    );
    _hapticTimers.add(
      Timer(const Duration(milliseconds: 760), () {
        HapticFeedback.selectionClick();
      }),
    );
  }

  @override
  void dispose() {
    for (final timer in _hapticTimers) {
      timer.cancel();
    }
    _hapticTimers.clear();
    _waveController.dispose();
    _cardController.dispose();
    _badgeController.dispose();
    _ambientController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    HapticFeedback.lightImpact();

    // Smooth exit transition
    _cardController.reverse(from: _cardController.value);
    _waveController.reverse(from: _waveController.value);

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        widget.onDismiss?.call();
        Navigator.of(context).maybePop();
      }
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta != null && details.primaryDelta! > 0) {
      setState(() {
        _dragOffsetY = math.max(0, _dragOffsetY + details.primaryDelta!);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffsetY > 110 ||
        (details.primaryVelocity != null && details.primaryVelocity! > 500)) {
      _dismiss();
    } else {
      setState(() {
        _dragOffsetY = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final nowStr = DateFormat('hh:mm a • EEEE, d MMM').format(DateTime.now());

    final waveColors = _resolvedStyle.waveColors;
    final primaryAccent = _resolvedStyle.primaryColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Stack(
          children: [
            // 1. Deep Atmospheric Vignette & Frost Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 1.3,
                      colors: [
                        AppColors.headerBlue.withValues(alpha: 0.58),
                        AppColors.primaryDark.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Harmonic Fluid Liquid Light Wave & Concentric Ripples
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _waveController,
                  _ambientController,
                  _shimmerController,
                ]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _IosNameDropWavePainter(
                      progress: _fluidStretch.value,
                      glowAlpha: _waveGlow.value,
                      ambientPulse: _ambientController.value,
                      shimmerPhase: _shimmerController.value,
                      particles: _particles,
                      waveColors: waveColors,
                      primaryAccent: primaryAccent,
                    ),
                  );
                },
              ),
            ),

            // 3. Top Emitter (Dynamic Island / Notch Luminous Glow Meniscus)
            Positioned(
              top: topPadding > 0 ? topPadding - 4 : 8,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    final progress = _waveController.value;
                    final width = 110.0 + (progress * 70.0);
                    return Container(
                      width: width,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.95 * _waveGlow.value),
                            waveColors[0].withValues(alpha: 0.85 * _waveGlow.value),
                            waveColors[1].withValues(alpha: 0.70 * _waveGlow.value),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.75 * _waveGlow.value),
                            blurRadius: 16,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: primaryAccent.withValues(alpha: 0.6 * _waveGlow.value),
                            blurRadius: 28,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 4. Floating Frosted-Glass Attendance Confirmation Card
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.screenPadding,
                  ),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_cardController, _ambientController]),
                    builder: (context, child) {
                      final totalOffsetY = _cardSlide.value + _dragOffsetY;
                      return Transform.translate(
                        offset: Offset(0, totalOffsetY),
                        child: Transform.scale(
                          scale: _cardScale.value *
                              (1.0 - (_dragOffsetY / 1200).clamp(0.0, 0.2)),
                          child: Opacity(
                            opacity: _cardOpacity.value *
                                (1.0 - (_dragOffsetY / 400).clamp(0.0, 0.8)),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // Prevent taps on card from dismissing
                      onVerticalDragUpdate: _onVerticalDragUpdate,
                      onVerticalDragEnd: _onVerticalDragEnd,
                      child: _buildNameDropCard(nowStr),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameDropCard(String nowStr) {
    final waveColors = _resolvedStyle.waveColors;
    final primaryAccent = _resolvedStyle.primaryColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 390),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryAccent.withValues(alpha: 0.28),
                blurRadius: 36,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Swipe down drag handle indicator
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Animated luminous gradient top highlight bar
              AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, _) {
                  return Container(
                    height: 3.5,
                    margin: const EdgeInsets.symmetric(horizontal: 55, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          waveColors[0],
                          waveColors[1],
                          waveColors.length > 2 ? waveColors[2] : waveColors[1],
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: primaryAccent.withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
                child: Column(
                  children: [
                    // Stamped Checkmark Emblem with expanding halo
                    _buildRadiantBadge(),

                    const SizedBox(height: 18),

                    // "ATTENDANCE VERIFIED" Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                        border: Border.all(
                          color: AppColors.successGreen.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.successGreen.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ATTENDANCE VERIFIED',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4ADE80),
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Main Title: "Attendance Marked!"
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline.copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Session Name with Event Icon/Emoji
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _resolvedStyle.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.sessionName,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.title.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Optional Student Room / Room badge
                    if (widget.roomNo != null && widget.roomNo!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Room ${widget.roomNo}',
                          style: AppTextStyles.bodySm.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Timestamp
                    Text(
                      nowStr,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm.copyWith(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Descriptive Subtitle (if available)
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.80),
                          height: 1.45,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Interactive Done Action Button matching AppColors.buttonGradient
                    _buildDoneButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneButton() {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isButtonPressed = true);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        setState(() => _isButtonPressed = false);
        _dismiss();
      },
      onTapCancel: () {
        setState(() => _isButtonPressed = false);
      },
      child: AnimatedScale(
        scale: _isButtonPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          height: AppDimens.buttonHeight,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: AppColors.primaryLight.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Done',
                style: AppTextStyles.button.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadiantBadge() {
    return AnimatedBuilder(
      animation: Listenable.merge([_badgeController, _ambientController]),
      builder: (context, _) {
        final scale = _badgeScale.value;
        final pulse = _ambientController.value;
        final haloRadius = 76.0 + (pulse * 12.0);

        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer expanding caustic ripple ring
              Opacity(
                opacity: (0.45 * _badgeHalo.value * (1.0 - pulse * 0.3)).clamp(0.0, 1.0),
                child: Container(
                  width: haloRadius,
                  height: haloRadius,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.successGreen.withValues(alpha: 0.5),
                        _resolvedStyle.primaryColor.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Glass badge core with punchy entrance scale
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF34D399), // Emerald bright
                        AppColors.successGreen, // Brand success green (#2E7D32)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF34D399).withValues(alpha: 0.6),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: AppColors.successGreen.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Particle model for NameDrop stardust light streaks
class _NameDropStardust {
  final double angle;
  final double speed;
  final double length;
  final double strokeWidth;
  final double alpha;
  final int colorIndex;

  _NameDropStardust({
    required this.angle,
    required this.speed,
    required this.length,
    required this.strokeWidth,
    required this.alpha,
    required this.colorIndex,
  });
}

/// Custom painter for the Apple iOS 17 NameDrop liquid wave,
/// fluid meniscus, concentric ripples, and stardust particle trails.
class _IosNameDropWavePainter extends CustomPainter {
  final double progress;
  final double glowAlpha;
  final double ambientPulse;
  final double shimmerPhase;
  final List<_NameDropStardust> particles;
  final List<Color> waveColors;
  final Color primaryAccent;

  _IosNameDropWavePainter({
    required this.progress,
    required this.glowAlpha,
    required this.ambientPulse,
    required this.shimmerPhase,
    required this.particles,
    required this.waveColors,
    required this.primaryAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glowAlpha <= 0.001) return;

    final origin = Offset(size.width / 2, 0);
    final maxReach = size.height * (0.32 + (progress * 0.24));
    final w = size.width;

    // 1. Broad Radiant Warm Nebula Glow from top notch
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -1.0),
        radius: 1.35,
        colors: [
          Colors.white.withValues(alpha: 0.90 * glowAlpha),
          waveColors[0].withValues(alpha: 0.70 * glowAlpha),
          waveColors[1].withValues(alpha: 0.55 * glowAlpha),
          (waveColors.length > 2 ? waveColors[2] : primaryAccent)
              .withValues(alpha: 0.35 * glowAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.52, 0.78, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, maxReach * 1.55));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, maxReach * 1.6),
      nebulaPaint,
    );

    // 2. Liquid Wave Drop (Harmonic Surface Wave Contouring)
    // Multi-frequency sine/cosine wave creates authentic fluid liquid surface tension
    final dropPath = Path();
    final stretchY = maxReach * 0.92;
    final wavePhase = shimmerPhase * 2 * math.pi;

    dropPath.moveTo(0, 0);
    dropPath.lineTo(w, 0);

    // Right curve down
    dropPath.quadraticBezierTo(
      w * 0.92,
      stretchY * 0.3,
      w * 0.68,
      stretchY * 0.72,
    );

    // Harmonic liquid apex with wave ripple
    final apexCenterY = stretchY * (1.02 + (ambientPulse * 0.08));
    final harmonicOffset = math.sin(wavePhase) * 6.0;

    dropPath.cubicTo(
      w * 0.58,
      apexCenterY + harmonicOffset,
      w * 0.42,
      apexCenterY - harmonicOffset,
      w * 0.32,
      stretchY * 0.72,
    );

    // Left curve back to top-left
    dropPath.quadraticBezierTo(
      w * 0.08,
      stretchY * 0.3,
      0,
      0,
    );
    dropPath.close();

    final fluidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.92 * glowAlpha),
          waveColors[0].withValues(alpha: 0.75 * glowAlpha),
          waveColors[1].withValues(alpha: 0.45 * glowAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, stretchY * 1.18));

    canvas.drawPath(dropPath, fluidPaint);

    // 3. Concentric Caustic Wave Ripples (iOS NameDrop signature)
    for (int i = 1; i <= 4; i++) {
      final ringRadius = (maxReach * 0.36 * i) + (ambientPulse * 22.0 * i);
      final ringAlpha = (1.0 - (ringRadius / (size.height * 0.70))).clamp(0.0, 1.0) *
          0.48 *
          glowAlpha;

      if (ringAlpha <= 0.01) continue;

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 + (4 - i) * 1.2
        ..shader = RadialGradient(
          colors: [
            waveColors[0].withValues(alpha: ringAlpha),
            waveColors[1].withValues(alpha: ringAlpha * 0.65),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: origin, radius: ringRadius),
        );

      canvas.drawCircle(origin, ringRadius, ringPaint);
    }

    // 4. Stardust Particle Streaks radiating from notch along wave vectors
    final particleProgress = (progress * 1.25).clamp(0.0, 1.0);
    for (final p in particles) {
      final currentDist = p.speed * particleProgress;
      if (currentDist <= 6) continue;

      final dx = origin.dx + math.cos(p.angle) * currentDist;
      final dy = origin.dy + math.sin(p.angle) * currentDist;

      final tailDx = origin.dx +
          math.cos(p.angle) * math.max(0.0, currentDist - p.length);
      final tailDy = origin.dy +
          math.sin(p.angle) * math.max(0.0, currentDist - p.length);

      final pColor = p.colorIndex == 0
          ? Colors.white
          : (p.colorIndex == 1 ? waveColors[0] : waveColors[1]);

      final pAlpha = (p.alpha *
              glowAlpha *
              (1.0 - (currentDist / (size.height * 0.88))))
          .clamp(0.0, 1.0);

      if (pAlpha <= 0.01) continue;

      final pPaint = Paint()
        ..color = pColor.withValues(alpha: pAlpha)
        ..strokeWidth = p.strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(tailDx, tailDy), Offset(dx, dy), pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IosNameDropWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowAlpha != glowAlpha ||
        oldDelegate.ambientPulse != ambientPulse ||
        oldDelegate.shimmerPhase != shimmerPhase ||
        oldDelegate.primaryAccent != primaryAccent;
  }
}
