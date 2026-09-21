import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/image_assets.dart';

/// Full-bleed brand gradient with soft decorative orbs. Stand-in for
/// assets/images/login_screen_bg.jpeg until the real asset is supplied.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          Positioned(top: -120, right: -80, child: _orb(320, 0.10)),
          Positioned(top: 180, left: -120, child: _orb(260, 0.06)),
          Positioned(bottom: -100, right: -60, child: _orb(240, 0.08)),
        ],
      ),
    );
  }

  Widget _orb(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha * 1.6),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

/// App mark displaying the official hostel building logo.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        ImageAssets.appLogo,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.apartment_rounded,
          color: AppColors.primary,
          size: size * 0.5,
        ),
      ),
    );
  }
}
