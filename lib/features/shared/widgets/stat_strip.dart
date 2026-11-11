import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import 'app_card.dart';

/// One number in a [StatStrip].
class StatStripItem {
  final String value;
  final String label;
  final Color color;

  const StatStripItem({required this.value, required this.label, this.color = AppColors.textPrimary});
}

/// A card of evenly spaced numbers with one-line captions underneath, e.g.
/// Targeted / Answered / Seen only / Not seen. Values always line up because
/// every caption is kept to one line.
class StatStrip extends StatelessWidget {
  final List<StatStripItem> items;

  const StatStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.gapLg, horizontal: AppDimens.gapSm),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: AppColors.borderLight),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].value,
                        style: AppTextStyles.headline.copyWith(color: items[i].color),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
