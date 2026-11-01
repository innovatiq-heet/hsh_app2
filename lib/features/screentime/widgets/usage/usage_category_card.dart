import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../controllers/screen_time_utils.dart';
import 'usage_style.dart';

/// Where the selected day's time went, by kind of app: a donut with the total
/// in the middle, and a row per category with its minutes and share.
class UsageCategoryCard extends StatelessWidget {
  /// Minutes per category (Social Media, Gaming, ...) for the selected day.
  final Map<String, int> categories;

  const UsageCategoryCard({super.key, required this.categories});

  /// Categories with time, biggest first.
  static List<MapEntry<String, int>> ranked(Map<String, int> categories) =>
      categories.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));

  @override
  Widget build(BuildContext context) {
    final entries = ranked(categories);
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UsageCardHeader(
            title: 'What the time went on',
            subtitle: 'By kind of app, for the selected day',
          ),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.gapMd),
              child: Text(
                'No per-app breakdown for this day yet.',
                style: AppTextStyles.bodySm,
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(enabled: false),
                          sections: [
                            for (final e in entries)
                              PieChartSectionData(
                                value: e.value.toDouble(),
                                color: UsageColors.category(e.key),
                                radius: 20,
                                showTitle: false,
                              ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatMinutes(total), style: AppTextStyles.title.copyWith(fontSize: 15)),
                          Text('total', style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.gapLg),
                Expanded(
                  child: Column(
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: UsageColors.category(e.key),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMd.copyWith(fontSize: 13),
                                ),
                              ),
                              Text(
                                '${(e.value * 100 / total).round()}%',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 13,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
