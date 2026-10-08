import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isBounded = constraints.hasBoundedWidth;
          final titleWidget = Text(
            title,
            style: AppTextStyles.title,
            overflow: TextOverflow.ellipsis,
          );

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (isBounded)
                Expanded(child: titleWidget)
              else
                titleWidget,
              ?trailing,
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: AppDimens.gapSm),
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
                    style: AppTextStyles.label.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
