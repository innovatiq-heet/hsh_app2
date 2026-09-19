import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outline, danger, text }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  bool get _disabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget button = switch (variant) {
      AppButtonVariant.primary => _FilledGradientButton(
        gradient: AppColors.buttonGradient,
        glow: AppColors.primary,
        onPressed: _disabled ? null : onPressed,
        expand: expand,
        child: _content(Colors.white),
      ),
      AppButtonVariant.secondary => _FilledGradientButton(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.primaryLight],
        ),
        glow: AppColors.secondary,
        onPressed: _disabled ? null : onPressed,
        expand: expand,
        child: _content(Colors.white),
      ),
      AppButtonVariant.danger => _FilledGradientButton(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), AppColors.cancelledRed],
        ),
        glow: AppColors.cancelledRed,
        onPressed: _disabled ? null : onPressed,
        expand: expand,
        child: _content(Colors.white),
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: _disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.4),
          minimumSize: Size(
            expand ? double.infinity : 0,
            AppDimens.buttonHeight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
        child: _content(AppColors.primary),
      ),
      AppButtonVariant.text => TextButton(
        onPressed: _disabled ? null : onPressed,
        child: _content(AppColors.primary),
      ),
    };

    return expand
        ? LayoutBuilder(
            builder: (context, constraints) {
              if (!constraints.hasBoundedWidth) {
                return button;
              }
              return SizedBox(width: double.infinity, child: button);
            },
          )
        : button;
  }

  Widget _content(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppDimens.gapSm),
        ],
        Text(label, style: AppTextStyles.button.copyWith(color: color)),
      ],
    );
  }
}

class _FilledGradientButton extends StatelessWidget {
  final Gradient gradient;
  final Color glow;
  final VoidCallback? onPressed;
  final bool expand;
  final Widget child;

  const _FilledGradientButton({
    required this.gradient,
    required this.glow,
    required this.onPressed,
    required this.expand,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(AppDimens.radiusMd);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldExpand = expand && constraints.hasBoundedWidth;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: radius,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox(
                  height: AppDimens.buttonHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      widthFactor: shouldExpand ? null : 1,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
