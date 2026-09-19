import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';

/// Hero header for top-level screens: brand gradient, rounded bottom
/// corners, soft decorative circles, and an optional [child] slot for
/// summary content (stats, balance, progress). Place it as the first item of
/// a scroll view instead of using an AppBar.
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? overline;
  final List<Widget> actions;
  final Widget? child;
  final Widget? leading;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.actions = const [],
    this.child,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimens.radiusXl + 4),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              const Positioned(
                top: -70,
                right: -50,
                child: _Orb(size: 220, alpha: 0.10),
              ),
              const Positioned(
                bottom: -60,
                left: -40,
                child: _Orb(size: 160, alpha: 0.07),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapMd,
                    AppDimens.screenPadding,
                    AppDimens.gapXl + 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: AppDimens.gapMd),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (overline != null)
                                  Text(
                                    overline!.toUpperCase(),
                                    style: AppTextStyles.overline.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                Text(
                                  title,
                                  style: AppTextStyles.displayMd.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ...actions,
                        ],
                      ),
                      if (child != null) ...[
                        const SizedBox(height: AppDimens.gapXl),
                        child!,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent circular icon button for use inside [GradientHeader].
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppDimens.gapSm),
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Frosted pill used for small stats/labels inside a [GradientHeader].
class HeaderPill extends StatelessWidget {
  final IconData? icon;
  final String label;

  const HeaderPill({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double alpha;

  const _Orb({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}
