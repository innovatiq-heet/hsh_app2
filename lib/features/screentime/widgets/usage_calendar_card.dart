import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/screen_time_utils.dart';
import '../controllers/student_detail_controller.dart';
import 'student_detail_widget.dart';

/// Month calendar of one student's screen time. Each day shows its total and
/// is tinted by how heavy it was (red once it went over the daily limit);
/// tapping a day selects it, and the day's details show below the calendar.
class UsageCalendarCard extends StudentDetailWidget {
  const UsageCalendarCard({super.key, required super.controller});

  @override
  Widget build(BuildContext context) => _CalendarBody(controller: controller);

  /// The grid of a month, Monday first: leading blanks (`null`), then days 1..N.
  static List<int?> monthCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = first.weekday - DateTime.monday; // Mon = 0 ... Sun = 6
    return [for (var i = 0; i < lead; i++) null, for (var d = 1; d <= days; d++) d];
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Compact minutes for a small cell: "45m", "2h", "2h 5m".
  static String shortMinutes(int mins) => formatMinutes(mins);
}

class _CalendarBody extends StatefulWidget {
  final StudentDetailController controller;
  const _CalendarBody({required this.controller});

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  StudentDetailController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final today = DateTime.now();
      final thisMonth = DateTime(today.year, today.month);
      final earliest = _earliestMonth(thisMonth);
      final canGoBack = _month.isAfter(earliest);
      final canGoForward = _month.isBefore(thisMonth);

      final cells = UsageCalendarCard.monthCells(_month);
      final limit = controller.dailyLimitMinutes.value;
      final selected = controller.effectiveSelectedDate;

      // Minutes per day of this month; the heaviest day sets the colour scale
      // when there is no daily limit.
      final minutes = <int, int?>{};
      var monthMax = 0;
      for (final d in cells.whereType<int>()) {
        final date = DateTime(_month.year, _month.month, d);
        final m = date.isAfter(today) ? null : controller.minutesOnDate(UsageCalendarCard.dateKey(date));
        minutes[d] = m;
        if (m != null && m > monthMax) monthMax = m;
      }
      final scale = limit > 0 ? limit : (monthMax > 0 ? monthMax : 1);

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                  onPressed: canGoBack ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(DateFormat('MMMM yyyy').format(_month), style: AppTextStyles.title),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                  onPressed: canGoForward ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.gapSm),
            Row(
              children: [
                for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(w, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.82,
              children: [
                for (final d in cells)
                  if (d == null)
                    const SizedBox.shrink()
                  else
                    _DayCell(
                      day: d,
                      minutes: minutes[d],
                      scale: scale,
                      limit: limit,
                      isToday: today.year == _month.year && today.month == _month.month && today.day == d,
                      isSelected: selected == UsageCalendarCard.dateKey(DateTime(_month.year, _month.month, d)),
                      isFuture: DateTime(_month.year, _month.month, d).isAfter(today),
                      onTap: () => controller.selectDate(
                        UsageCalendarCard.dateKey(DateTime(_month.year, _month.month, d)),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: AppDimens.gapSm),
            Text(
              limit > 0
                  ? 'Darker means closer to the ${formatMinutes(limit)} daily limit; red means over it.'
                  : 'Darker means more screen time that day.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    });
  }

  /// The first month with any record, so the calendar can't wander into
  /// months with nothing in them.
  DateTime _earliestMonth(DateTime thisMonth) {
    var earliest = thisMonth;
    for (final r in controller.historyRecords) {
      final d = DateTime.tryParse(extractRecordDate(r));
      if (d != null) {
        final m = DateTime(d.year, d.month);
        if (m.isBefore(earliest)) earliest = m;
      }
    }
    return earliest;
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int? minutes;
  final int scale;
  final int limit;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.minutes,
    required this.scale,
    required this.limit,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = minutes;
    final over = limit > 0 && m != null && m > limit;
    final tint = over ? AppColors.cancelledRed : AppColors.primary;
    final intensity = m == null || m <= 0 ? 0.0 : (m / scale).clamp(0.12, 1.0);
    final background = m == null || m <= 0
        ? AppColors.surfaceMuted
        : tint.withValues(alpha: 0.10 + 0.45 * intensity);

    return Opacity(
      opacity: isFuture ? 0.35 : 1,
      child: InkWell(
        onTap: isFuture ? null : onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : (isToday ? AppColors.primary : Colors.transparent),
              width: isSelected ? 2 : 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: AppTextStyles.bodyMd.copyWith(
                  fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                m == null || m <= 0 ? '' : UsageCalendarCard.shortMinutes(m),
                maxLines: 1,
                style: AppTextStyles.caption.copyWith(fontSize: 8.5, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
