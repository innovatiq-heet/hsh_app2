import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';
import 'icon_badge.dart';

class SectionListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const SectionListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.gapMd,
          horizontal: AppDimens.gapSm,
        ),
        child: Row(
          children: [
            IconBadge(icon: icon, color: iconColor ?? AppColors.primary),
            const SizedBox(width: AppDimens.gapLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle.copyWith(
                      color: iconColor == AppColors.cancelledRed
                          ? AppColors.cancelledRed
                          : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTextStyles.bodySm),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
          ],
        ),
      ),
    );
  }
}
