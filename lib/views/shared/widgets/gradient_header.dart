import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';
import 'aurora_background.dart';
import 'fade_slide_in.dart';
import 'pressable.dart';

/// Hero header for top-level screens: animated aurora backdrop, rounded
/// bottom corners, and an optional [child] slot for summary content (stats,
/// balance, progress). Place it as the first item of a scroll view instead
/// of using an AppBar.
///
/// [bottomInset] adds extra space at the bottom so a row of cards can
/// float over the header's lower edge (see Profile).
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? overline;
  final List<Widget> actions;
  final Widget? child;
  final Widget? leading;
  final double bottomInset;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.actions = const [],
    this.child,
    this.leading,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimens.radiusXl + 6),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: AuroraBackground()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapMd,
                  AppDimens.screenPadding,
                  AppDimens.gapXl + 4 + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideIn(
                      offset: 14,
                      child: Row(
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
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  style: AppTextStyles.displayMd.copyWith(
                                    color: Colors.white,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ...actions,
                        ],
                      ),
                    ),
                    if (child != null) ...[
                      const SizedBox(height: AppDimens.gapXl),
                      FadeSlideIn(index: 2, offset: 18, child: child!),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
      child: Pressable(
        pressedScale: 0.9,
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          shape: const CircleBorder(side: BorderSide(color: AppColors.glassBorder)),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Translucent pill for small labels inside a [GradientHeader].
class HeaderPill extends StatelessWidget {
  final IconData? icon;
  final String label;

  const HeaderPill({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: AppColors.glassBorder),
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

/// Translucent panel for summary content inside a [GradientHeader] (no
/// backdrop blur — the aurora behind it animates, and re-blurring a moving
/// layer every frame is costly).
class HeaderPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HeaderPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.gapLg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: child,
    );
  }
}
