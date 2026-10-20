import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';

/// Consistent chrome for the screen-time bottom sheets: grab handle, title
/// row with close button, keyboard-safe padding, scrollable body.
class SheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const SheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        10,
        AppDimens.screenPadding,
        AppDimens.gapXl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headline),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: Get.back,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapLg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
