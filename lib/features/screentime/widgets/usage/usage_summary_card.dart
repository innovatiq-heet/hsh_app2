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

/// The selected day at a glance: its total, how it compares with the period's
/// average, a ring for the share of the daily limit used, and three numbers
/// about the period.
class UsageSummaryCard extends StatelessWidget {
  final UsageAnalytics analytics;

  /// `yyyy-MM-dd` of the selected day.
  final String date;
  final bool isToday;
  final int minutes;
  final int night;

  /// Called by "Back to today" when another day is selected.
  final VoidCallback? onBackToToday;

  const UsageSummaryCard({
    super.key,
    required this.analytics,
    required this.date,
    required this.isToday,
    required this.minutes,
    required this.night,
    this.onBackToToday,
  });

  @override
  Widget build(BuildContext context) {
    final limit = analytics.limit;
    final over = limit > 0 && minutes > limit;
    final parsed = DateTime.tryParse(date);
    final title = isToday
        ? 'Today'
        : (parsed == null ? date : DateFormat('EEE, d MMM').format(parsed));
    final delta = analytics.percentVsAverage(minutes);

    // Ring: share of the daily limit, or of the period's heaviest day when
    // there is no limit.
    final basis = limit > 0 ? limit : analytics.maxMinutes;
    final share = basis > 0 ? (minutes / basis).clamp(0.0, 1.0) : 0.0;
    final ringColor = over ? UsageColors.over : UsageColors.day;

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title.toUpperCase(), style: AppTextStyles.overline)),
              if (!isToday && onBackToToday != null)
                TextButton(
                  onPressed: onBackToToday,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Back to today'),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      minutes > 0 ? formatMinutes(minutes) : 'No usage',
                      style: AppTextStyles.displayLg.copyWith(
                        color: over ? UsageColors.over : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapSm),
                    if (delta != null && minutes > 0) _DeltaChip(percent: delta),
                    if (over) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${formatMinutes(minutes - limit)} over the ${formatMinutes(limit)} limit',
                        style: AppTextStyles.bodySm.copyWith(color: UsageColors.over),
                      ),
                    ],
                  ],
                ),
              ),
              _Ring(share: share, color: ringColor, caption: limit > 0 ? 'of limit' : 'of peak day'),
            ],
          ),
          const SizedBox(height: AppDimens.gapLg),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppDimens.gapMd),
          Row(
            children: [
              _Stat(
                icon: Icons.show_chart_rounded,
                color: UsageColors.day,
                value: analytics.averageMinutes > 0 ? formatMinutes(analytics.averageMinutes) : '—',
                label: 'Daily average',
              ),
              _Stat(
                icon: Icons.nightlight_round,
                color: UsageColors.night,
                value: night > 0 ? formatMinutes(night) : '—',
                label: 'At night',
              ),
              _Stat(
                icon: limit > 0 ? Icons.hourglass_disabled_rounded : Icons.event_available_rounded,
                color: limit > 0 && analytics.overLimitDays > 0 ? UsageColors.over : AppColors.successGreen,
                value: limit > 0 ? '${analytics.overLimitDays}' : '${analytics.activeDays}',
                label: limit > 0 ? 'Days over limit' : 'Days tracked',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final int percent;
  const _DeltaChip({required this.percent});

  @override
  Widget build(BuildContext context) {
    final up = percent > 0;
    final flat = percent == 0;
    final color = flat ? AppColors.textSecondary : (up ? UsageColors.over : AppColors.successGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flat ? Icons.remove_rounded : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            flat ? 'Same as average' : '${percent.abs()}% ${up ? 'above' : 'below'} average',
            style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double share;
  final Color color;
  final String caption;
  const _Ring({required this.share, required this.color, required this.caption});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: 33,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                PieChartSectionData(
                  value: share <= 0 ? 0.0001 : share,
                  color: color,
                  radius: 11,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (1 - share).clamp(0.0, 1.0) <= 0 ? 0.0001 : 1 - share,
                  color: AppColors.primarySoft,
                  radius: 11,
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
              Text(
                '${(share * 100).round()}%',
                style: AppTextStyles.title.copyWith(fontSize: 16, color: color),
              ),
              Text(caption, style: AppTextStyles.caption.copyWith(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.subtitle.copyWith(fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
