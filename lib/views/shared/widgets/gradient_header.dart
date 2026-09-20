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
  final Widget? heroLeading;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.actions = const [],
    this.child,
    this.leading,
    this.heroLeading,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      sized: false,
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
                          if (heroLeading != null) ...[
                            heroLeading!,
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

/// Collapsible pinned sliver header that smoothly collapses on scroll and keeps
/// a sticky top portion pinned with the screen title, back button, and actions.
class SliverGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? overline;
  final List<Widget> actions;
  final Widget? child;
  final Widget? leading;
  final Widget? heroLeading;
  final double? expandedHeight;

  const SliverGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.actions = const [],
    this.child,
    this.leading,
    this.heroLeading,
    this.expandedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final minH = kToolbarHeight + topPadding;
    final calculatedExpanded = expandedHeight ??
        (child != null
            ? 250.0
            : (subtitle != null ? 180.0 : 140.0));
    final maxH = (calculatedExpanded + topPadding).clamp(minH, 650.0);

    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverGradientHeaderDelegate(
        title: title,
        subtitle: subtitle,
        overline: overline,
        actions: actions,
        child: child,
        leading: leading,
        heroLeading: heroLeading,
        topPadding: topPadding,
        minHeight: minH,
        maxHeight: maxH,
      ),
    );
  }
}

class _SliverGradientHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String? subtitle;
  final String? overline;
  final List<Widget> actions;
  final Widget? child;
  final Widget? leading;
  final Widget? heroLeading;
  final double topPadding;
  final double minHeight;
  final double maxHeight;

  _SliverGradientHeaderDelegate({
    required this.title,
    this.subtitle,
    this.overline,
    this.actions = const [],
    this.child,
    this.leading,
    this.heroLeading,
    required this.topPadding,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  bool shouldRebuild(covariant _SliverGradientHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.overline != overline ||
        oldDelegate.actions != actions ||
        oldDelegate.child != child ||
        oldDelegate.leading != leading ||
        oldDelegate.heroLeading != heroLeading ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final shrinkRange = maxHeight - minHeight;
    final progress = shrinkRange <= 0
        ? 0.0
        : (shrinkOffset / shrinkRange).clamp(0.0, 1.0);

    // Opacity curves
    final expandedOpacity = (1.0 - progress * 1.6).clamp(0.0, 1.0);
    final collapsedOpacity = ((progress - 0.40) * 2.0).clamp(0.0, 1.0);

    // Dynamic bottom radius (e.g. 32 down to 14 when pinned)
    final bottomRadius = (1.0 - progress) * 18.0 + 14.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      sized: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(bottomRadius),
          ),
          boxShadow: progress > 0.05
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14 * progress),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Decorative background orbs
            Positioned(
              top: -70 + (shrinkOffset * 0.2),
              right: -50,
              child: const _Orb(size: 220, alpha: 0.10),
            ),
            Positioned(
              bottom: -60 - (shrinkOffset * 0.2),
              left: -40,
              child: const _Orb(size: 160, alpha: 0.07),
            ),

            // Expanded body content (fades out as header collapses)
            if (expandedOpacity > 0)
              Positioned(
                top: topPadding + kToolbarHeight,
                left: AppDimens.screenPadding,
                right: AppDimens.screenPadding,
                bottom: 0,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -15 * progress),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (heroLeading != null) ...[
                                heroLeading!,
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
                            ],
                          ),
                          if (child != null) ...[
                            const SizedBox(height: AppDimens.gapLg),
                            child!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Pinned sticky top bar (stays fixed at top)
            Positioned(
              top: topPadding,
              left: 0,
              right: 0,
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.screenPadding,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: AppDimens.gapSm),
                    ],
                    Expanded(
                      child: Opacity(
                        opacity: collapsedOpacity,
                        child: Text(
                          title,
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    ...actions,
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
