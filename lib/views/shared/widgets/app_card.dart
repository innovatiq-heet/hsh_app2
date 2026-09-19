import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import 'pressable.dart';

/// Base surface for every card in the app: layered depth via a hairline
/// gradient border and a tinted two-layer ambient shadow. Pass [gradient]
/// for hero-style cards (balance, net due, ...). Tappable cards get tactile
/// scale feedback automatically.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.cardPadding),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = AppDimens.radiusLg,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final isHero = gradient != null;
    final outer = BorderRadius.circular(radius);
    final inner = BorderRadius.circular(radius - 1);

    final card = Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: outer,
        gradient: isHero
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.04),
                ],
              )
            : AppColors.cardBorderGradient,
        boxShadow: elevated
            ? (isHero
                  ? AppColors.tintedShadow(AppColors.indigo, 0.30)
                  : AppColors.softShadow)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: inner,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: isHero ? null : (color ?? AppColors.surface),
            gradient: gradient,
            borderRadius: inner,
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    return Pressable(enabled: onTap != null, child: card);
  }
}
