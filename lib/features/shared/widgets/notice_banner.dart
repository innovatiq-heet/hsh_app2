import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';

/// A tinted note with an icon: warnings, "you already answered", reach of a
/// broadcast. Pass [message] for plain text or [child] for richer content.
class NoticeBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? message;
  final Widget? child;

  /// Optional trailing widget, e.g. a Retry button.
  final Widget? action;

  const NoticeBanner({
    super.key,
    required this.icon,
    this.color = AppColors.primaryLight,
    this.message,
    this.child,
    this.action,
  }) : assert(message != null || child != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppDimens.gapLg, AppDimens.gapMd, AppDimens.gapLg, AppDimens.gapMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: DefaultTextStyle.merge(
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textPrimary, height: 1.35),
              child: child ?? Text(message!),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppDimens.gapSm),
            action!,
          ],
        ],
      ),
    );
  }
}
