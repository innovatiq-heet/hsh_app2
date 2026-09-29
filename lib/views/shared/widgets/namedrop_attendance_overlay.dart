import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// An iOS 17 NameDrop / Proximity Sharing style animation overlay.
/// Features a luminous top-edge fluid light wave, blooming nebula aura,
/// stardust particle streaks, synchronized haptic vibration pulses, and
/// a floating frosted-glass attendance verification card.
class NamedropAttendanceOverlay extends StatefulWidget {
  final String title;
  final String sessionName;
  final String? subtitle;
  final String? studentName;
  final String? roomNo;
  final VoidCallback? onDismiss;

  const NamedropAttendanceOverlay({
    super.key,
    this.title = 'Attendance Marked!',
    this.sessionName = 'Session',
    this.subtitle,
    this.studentName,
    this.roomNo,
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
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return NamedropAttendanceOverlay(
          title: title,
          sessionName: sessionName,
          subtitle: subtitle,
          studentName: studentName,
          roomNo: roomNo,
        );
      },
    );
  }

  @override
  State<NamedropAttendanceOverlay> createState() =>
      _NamedropAttendanceOverlayState();
}

class _NamedropAttendanceOverlayState extends State<NamedropAttendanceOverlay>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _cardController;
  late AnimationController _pulseController;

  late Animation<double> _fluidStretch;
  late Animation<double> _glowAlpha;
  late Animation<double> _cardSlide;
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;

  final List<_StardustParticle> _particles = [];
  Timer? _hapticTimer1;
  Timer? _hapticTimer2;
  Timer? _hapticTimer3;
  Timer? _hapticTimer4;

  @override
  void initState() {
    super.initState();

    // 1. Fluid wave animation (elastic pull down from top edge)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fluidStretch = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOutBack,
    );

    _glowAlpha = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // 2. Card entrance animation (springs down from under the top light wave)
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardSlide = Tween<double>(begin: -80, end: 0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutCubic,
      ),
    );

    _cardScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutBack,
      ),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );

    // 3. Continuous ambient breathing / shimmering
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Generate random particle streaks from the top center
    final random = math.Random(42);
    for (int i = 0; i < 36; i++) {
      _particles.add(
        _StardustParticle(
          angle: (random.nextDouble() * math.pi * 0.9) + (math.pi * 0.05), // downward fan
          speed: 160 + random.nextDouble() * 260,
          length: 12 + random.nextDouble() * 28,
          strokeWidth: 1.0 + random.nextDouble() * 2.2,
          alpha: 0.4 + random.nextDouble() * 0.6,
          hueOffset: random.nextDouble(),
        ),
      );
    }

    _startSequence();
  }

  void _startSequence() {
    // Stage 1: Initial touch haptic pulse
    HapticFeedback.lightImpact();

    _waveController.forward();

    // Stage 2: Rising magnetic hum (120ms)
    _hapticTimer1 = Timer(const Duration(milliseconds: 140), () {
      HapticFeedback.selectionClick();
    });

    // Stage 3: Apex fluid expansion & card pop (350ms)
    _hapticTimer2 = Timer(const Duration(milliseconds: 320), () {
      HapticFeedback.mediumImpact();
      if (mounted) _cardController.forward();
    });

    // Stage 4: NameDrop heavy lock confirmation (520ms)
    _hapticTimer3 = Timer(const Duration(milliseconds: 520), () {
      HapticFeedback.heavyImpact();
    });

    // Stage 5: Settle tick (700ms)
    _hapticTimer4 = Timer(const Duration(milliseconds: 720), () {
      HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _hapticTimer1?.cancel();
    _hapticTimer2?.cancel();
    _hapticTimer3?.cancel();
    _hapticTimer4?.cancel();
    _waveController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    widget.onDismiss?.call();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final nowStr = DateFormat('hh:mm a • EEEE, d MMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Stack(
          children: [
            // Background blur overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),

            // Top-edge NameDrop Liquid Light Aura & Particles
            AnimatedBuilder(
              animation: Listenable.merge([_waveController, _pulseController]),
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _NameDropAuraPainter(
                    progress: _fluidStretch.value,
                    glowAlpha: _glowAlpha.value,
                    pulse: _pulseController.value,
                    particles: _particles,
                  ),
                );
              },
            ),

            // Hardware Top Pill / Dynamic Island Glow Accent
            Positioned(
              top: topPadding > 0 ? topPadding - 6 : 8,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    final width = 110.0 + (_waveController.value * 60.0);
                    return Container(
                      width: width,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8 * _glowAlpha.value),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.6 * _glowAlpha.value),
                            blurRadius: 28,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Floating NameDrop Confirmation Card
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AnimatedBuilder(
                    animation: _cardController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _cardSlide.value),
                        child: Transform.scale(
                          scale: _cardScale.value,
                          child: Opacity(
                            opacity: _cardOpacity.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _buildNameDropCard(nowStr),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                blurRadius: 36,
                spreadRadius: -4,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dynamic light header bar
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 70, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00E5FF),
                      Color(0xFF8A2387),
                      Color(0xFFF27121),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                child: Column(
                  children: [
                    // Glowing Checkmark Emblem with rotating halo
                    _buildRadiantBadge(),

                    const SizedBox(height: 20),

                    // "VERIFIED ATTENDANCE" Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: Color(0xFF34D399),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'ATTENDANCE VERIFIED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF34D399),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Main Title
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Session Name
                    Text(
                      widget.sessionName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Timestamp
                    Text(
                      nowStr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Glass "Done" Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00E5FF),
                              Color(0xFF3B82F6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _dismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadiantBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final glowScale = 1.0 + (_pulseController.value * 0.12);
        return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer expanding aura
              Transform.scale(
                scale: glowScale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF10B981).withValues(alpha: 0.5),
                        const Color(0xFF00E5FF).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Glass badge base
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF34D399),
                      Color(0xFF059669),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
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
class _StardustParticle {
  final double angle;
  final double speed;
  final double length;
  final double strokeWidth;
  final double alpha;
  final double hueOffset;

  _StardustParticle({
    required this.angle,
    required this.speed,
    required this.length,
    required this.strokeWidth,
    required this.alpha,
    required this.hueOffset,
  });
}

/// Custom painter for the Apple NameDrop fluid light wave and cosmic glow.
class _NameDropAuraPainter extends CustomPainter {
  final double progress;
  final double glowAlpha;
  final double pulse;
  final List<_StardustParticle> particles;

  _NameDropAuraPainter({
    required this.progress,
    required this.glowAlpha,
    required this.pulse,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glowAlpha <= 0.001) return;

    final origin = Offset(size.width / 2, 0);
    final maxReach = size.height * (0.35 + (progress * 0.22));

    // 1. Draw Broad Cosmic Nebula Glow from the top edge
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -1.0),
        radius: 1.2,
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: 0.85 * glowAlpha),
          const Color(0xFF00F2FE).withValues(alpha: 0.70 * glowAlpha),
          const Color(0xFF7F00FF).withValues(alpha: 0.55 * glowAlpha),
          const Color(0xFFE100FF).withValues(alpha: 0.35 * glowAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.55, 0.80, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, maxReach * 1.4));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, maxReach * 1.5),
      nebulaPaint,
    );

    // 2. Liquid drop fluid bezier pulling downward from top
    final dropPath = Path();
    final stretchY = maxReach * 0.95;
    final w = size.width;

    dropPath.moveTo(0, 0);
    dropPath.lineTo(w, 0);
    dropPath.quadraticBezierTo(w * 0.9, stretchY * 0.35, w * 0.65, stretchY * 0.75);
    dropPath.quadraticBezierTo(w * 0.5, stretchY * (1.05 + pulse * 0.08), w * 0.35, stretchY * 0.75);
    dropPath.quadraticBezierTo(w * 0.1, stretchY * 0.35, 0, 0);
    dropPath.close();

    final fluidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.9 * glowAlpha),
          const Color(0xFF00E5FF).withValues(alpha: 0.65 * glowAlpha),
          const Color(0xFF9333EA).withValues(alpha: 0.35 * glowAlpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, stretchY * 1.15));

    canvas.drawPath(dropPath, fluidPaint);

    // 3. Concentric Shockwave Rings expanding from top-center
    for (int i = 1; i <= 3; i++) {
      final ringRadius = (maxReach * 0.45 * i) + (pulse * 25.0 * i);
      final ringAlpha = (1.0 - (ringRadius / (size.height * 0.75))).clamp(0.0, 1.0) *
          0.45 *
          glowAlpha;

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (3 - i) * 1.5
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00E5FF).withValues(alpha: ringAlpha),
            const Color(0xFFE879F9).withValues(alpha: ringAlpha * 0.6),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: origin, radius: ringRadius),
        );

      canvas.drawCircle(origin, ringRadius, ringPaint);
    }

    // 4. Stardust Particle Streaks radiating from top-center
    final particleProgress = (progress * 1.25).clamp(0.0, 1.0);
    for (final p in particles) {
      final currentDist = p.speed * particleProgress;
      if (currentDist <= 5) continue;

      final dx = origin.dx + math.cos(p.angle) * currentDist;
      final dy = origin.dy + math.sin(p.angle) * currentDist;

      final tailDx = origin.dx + math.cos(p.angle) * math.max(0.0, currentDist - p.length);
      final tailDy = origin.dy + math.sin(p.angle) * math.max(0.0, currentDist - p.length);

      final particleColor = Color.lerp(
        const Color(0xFFFFFFFF),
        const Color(0xFF00F2FE),
        p.hueOffset,
      )!;

      final pAlpha = (p.alpha * glowAlpha * (1.0 - (currentDist / (size.height * 0.9))))
          .clamp(0.0, 1.0);

      final pPaint = Paint()
        ..color = particleColor.withValues(alpha: pAlpha)
        ..strokeWidth = p.strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(tailDx, tailDy), Offset(dx, dy), pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NameDropAuraPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowAlpha != glowAlpha ||
        oldDelegate.pulse != pulse;
  }
}
