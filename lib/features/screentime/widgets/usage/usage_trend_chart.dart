import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../controllers/screen_time_utils.dart';
import '../../controllers/usage_analytics.dart';
import 'usage_style.dart';

/// Stacked bar per day (daytime in blue, night time on top in amber) with the
/// daily limit as a dashed line. Days over the limit turn red. Tap a bar to
/// select that day.
class UsageTrendChart extends StatelessWidget {
  final UsageAnalytics analytics;

  /// `yyyy-MM-dd` of the selected day.
  final String selectedDate;
  final ValueChanged<String> onSelectDate;

  const UsageTrendChart({
    super.key,
    required this.analytics,
    required this.selectedDate,
    required this.onSelectDate,
  });

  /// Top of the y axis in hours: room above the tallest bar and the limit.
  static double axisMaxHours(UsageAnalytics a) {
    final top = a.maxMinutes > a.limit ? a.maxMinutes : a.limit;
    final hours = (top / 60).ceil();
    return (hours < 2 ? 2 : hours).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final days = analytics.days;
    final maxY = axisMaxHours(analytics);
    final interval = maxY <= 4 ? 1.0 : (maxY <= 8 ? 2.0 : (maxY <= 16 ? 4.0 : 6.0));
    final many = days.length > 14;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppDimens.cardPadding, AppDimens.cardPadding, AppDimens.cardPadding, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UsageCardHeader(
            title: 'Daily screen time',
            subtitle: 'Tap a bar to see that day',
            trailing: analytics.limit > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: UsageColors.over.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Limit ${formatMinutes(analytics.limit)}',
                      style: AppTextStyles.caption.copyWith(color: UsageColors.over, fontWeight: FontWeight.w700),
                    ),
                  )
                : null,
          ),
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                groupsSpace: 4,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.borderLight, strokeWidth: 1, dashArray: [4, 4]),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (analytics.limit > 0)
                      HorizontalLine(
                        y: analytics.limit / 60,
                        color: UsageColors.over.withValues(alpha: 0.7),
                        strokeWidth: 1.4,
                        dashArray: [6, 4],
                      ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: interval,
                      getTitlesWidget: (value, meta) => value == 0
                          ? const SizedBox.shrink()
                          : Text('${value.toInt()}h', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        final d = days[i];
                        final selected = d.date == selectedDate;
                        final isLast = i == days.length - 1;
                        // 30 bars: label every fifth one (and today) so they stay readable.
                        if (many && !isLast && i % 5 != 0) return const SizedBox.shrink();
                        final top = many ? '${d.day.day}' : DateFormat('E').format(d.day).substring(0, 1);
                        final bottom = many ? DateFormat('MMM').format(d.day) : '${d.day.day}';
                        final color = selected ? AppColors.primary : AppColors.textMuted;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                top,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10.5,
                                  height: 1.2,
                                  color: color,
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              Text(bottom, style: AppTextStyles.caption.copyWith(fontSize: 9, height: 1.2, color: color)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    final spot = response?.spot;
                    if (event is FlTapUpEvent && spot != null) {
                      final i = spot.touchedBarGroupIndex;
                      if (i >= 0 && i < days.length) onSelectDate(days[i].date);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryDark,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = days[groupIndex];
                      final lines = StringBuffer(DateFormat('EEE, d MMM').format(d.day))
                        ..write('\n')
                        ..write(d.hasData ? formatMinutes(d.minutes) : 'No data');
                      if (d.night > 0) lines.write('\n${formatMinutes(d.night)} at night');
                      return BarTooltipItem(
                        lines.toString(),
                        AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++) _group(i, days[i], many),
                ],
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          const Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              LegendDot(color: UsageColors.day, label: 'Daytime'),
              LegendDot(color: UsageColors.night, label: 'Night'),
              LegendDot(color: UsageColors.over, label: 'Over limit'),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _group(int i, UsageDay d, bool thin) {
    final selected = d.date == selectedDate;
    final over = analytics.limit > 0 && d.minutes > analytics.limit;
    final base = over ? UsageColors.over : UsageColors.day;
    final fade = selected ? 1.0 : 0.62;
    final dayH = d.daytime / 60;
    final totalH = d.minutes / 60;
    final maxY = axisMaxHours(analytics);

    return BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: totalH,
          width: thin ? 7 : 18,
          borderRadius: BorderRadius.circular(thin ? 3 : 6),
          rodStackItems: totalH <= 0
              ? const []
              : [
                  BarChartRodStackItem(0, dayH, base.withValues(alpha: fade)),
                  if (d.night > 0)
                    BarChartRodStackItem(dayH, totalH, UsageColors.night.withValues(alpha: fade)),
                ],
          color: base.withValues(alpha: fade),
          backDrawRodData: BackgroundBarChartRodData(
            show: selected,
            toY: maxY,
            color: AppColors.primarySoft,
          ),
        ),
      ],
    );
  }
}
