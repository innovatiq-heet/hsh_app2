import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../controllers/screen_time_utils.dart';
import '../../controllers/usage_analytics.dart';
import 'usage_style.dart';

/// Behaviour over the period: the average for each weekday (which days run
/// heavy) and how the total splits between daytime and night.
class UsageRhythmCard extends StatelessWidget {
  final UsageAnalytics analytics;
  const UsageRhythmCard({super.key, required this.analytics});

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final averages = analytics.weekdayAverages;
    final known = averages.whereType<int>();
    final peak = known.isEmpty ? 0 : known.reduce((a, b) => a > b ? a : b);
    final maxY = ((peak / 60).ceil() < 1 ? 1 : (peak / 60).ceil()).toDouble();

    final day = analytics.daytimeMinutes;
    final night = analytics.nightMinutes;
    final total = day + night;
    final nightShare = total == 0 ? 0.0 : night / total;

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UsageCardHeader(
            title: 'Weekly rhythm',
            subtitle: 'Average screen time on each weekday',
          ),
          if (known.isEmpty)
            Text('Not enough days recorded yet.', style: AppTextStyles.bodySm)
          else
            SizedBox(
              height: 130,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i > 6) return const SizedBox.shrink();
                          final isPeak = averages[i] != null && averages[i] == peak;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdays[i],
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                                color: isPeak ? UsageColors.day : AppColors.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.primaryDark,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final m = averages[groupIndex];
                        return BarTooltipItem(
                          m == null ? 'No data' : formatMinutes(m),
                          AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (averages[i] ?? 0) / 60,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                            color: averages[i] == null
                                ? AppColors.primarySoft
                                : (averages[i] == peak ? UsageColors.day : UsageColors.day.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
            ),
          const SizedBox(height: AppDimens.gapLg),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppDimens.gapMd),
          Row(
            children: [
              Expanded(child: Text('Day and night', style: AppTextStyles.subtitle)),
              if (total > 0)
                Text(
                  '${(nightShare * 100).round()}% at night',
                  style: AppTextStyles.caption.copyWith(
                    color: night > 0 ? UsageColors.night : AppColors.successGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? const ColoredBox(color: AppColors.primarySoft)
                  : Row(
                      children: [
                        if (day > 0) Expanded(flex: day, child: const ColoredBox(color: UsageColors.day)),
                        if (night > 0) Expanded(flex: night, child: const ColoredBox(color: UsageColors.night)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          Row(
            children: [
              LegendDot(color: UsageColors.day, label: day > 0 ? 'Daytime ${formatMinutes(day)}' : 'Daytime'),
              const SizedBox(width: 16),
              LegendDot(color: UsageColors.night, label: night > 0 ? 'Night ${formatMinutes(night)}' : 'Night'),
            ],
          ),
        ],
      ),
    );
  }
}
