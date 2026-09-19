import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Frosted-glass surface: backdrop blur + translucent tint + a hairline
/// white border and a top-down sheen.
///
/// Backdrop blur is one of the more expensive effects to composite, so use
/// it for a few persistent surfaces (e.g. the nav bar), not every list item.
/// Set [blur] to 0 for a cheap translucent panel over static content.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color tint;
  final Color borderColor;
  final List<BoxShadow>? shadows;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 18,
    this.tint = AppColors.glassFill,
    this.borderColor = AppColors.glassBorder,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.08), tint),
            tint,
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: panel,
              )
            : panel,
      ),
    );
  }
}
