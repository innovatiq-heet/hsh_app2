import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../controllers/usage_analytics.dart';
import 'usage_style.dart';

/// Plain-language findings about the period (heaviest day, weekday pattern,
/// limit and night-time behaviour), so the charts don't need reading by eye.
class UsageInsightsCard extends StatelessWidget {
  final List<UsageInsight> insights;
  const UsageInsightsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UsageCardHeader(
            title: 'What stands out',
            subtitle: 'Worked out from the days above',
          ),
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.gapMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: insights[i].color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(insights[i].icon, size: 17, color: insights[i].color),
                ),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      insights[i].text,
                      style: AppTextStyles.bodyMd.copyWith(height: 1.35, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
