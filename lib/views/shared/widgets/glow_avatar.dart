import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';

/// Initials avatar ringed by a slowly rotating gradient halo with a soft
/// outer glow.
class GlowAvatar extends StatefulWidget {
  final String initials;
  final double size;

  const GlowAvatar({super.key, required this.initials, this.size = 64});

  @override
  State<GlowAvatar> createState() => _GlowAvatarState();
}

class _GlowAvatarState extends State<GlowAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Transform.rotate(
                angle: _controller.value * math.pi * 2,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        AppColors.cyan,
                        AppColors.indigo,
                        AppColors.violet,
                        AppColors.cyan,
                      ],
                    ),
                    boxShadow: AppColors.glow(AppColors.indigo, 0.6),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: size - 6,
            height: size - 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deepSlate,
            ),
          ),
          Container(
            width: size - 10,
            height: size - 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFDDE5FF)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.initials,
              style: AppTextStyles.headline.copyWith(
                color: AppColors.primary,
                fontSize: size * 0.36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
