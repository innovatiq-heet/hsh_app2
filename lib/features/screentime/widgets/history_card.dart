import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/student_screen_time_controller.dart';

/// Past days as a compact list; tapping one switches the whole page to it.
/// Collapsed to the most recent week by default.
class HistoryCard extends StatefulWidget {
  const HistoryCard({super.key});

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  static const _collapsedCount = 7;
  final controller = Get.find<StudentScreenTimeController>();
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final records = controller.historyRecords;
      if (records.isEmpty) return const SizedBox.shrink();

      final visible = _expanded ? records : records.take(_collapsedCount).toList();
      final maxMins = records.fold<int>(0, (m, r) => _mins(r) > m ? _mins(r) : m);
      final dateFmt = DateFormat('EEE, d MMM');

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Past days', style: AppTextStyles.title),
            const SizedBox(height: 2),
            Text(
              'Tap a day to see its apps and totals',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimens.gapMd),
            for (final rec in visible) _row(rec, maxMins, dateFmt),
            if (records.length > _collapsedCount)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                  label: Text(_expanded ? 'Show less' : 'Show all ${records.length} days'),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _row(dynamic rec, int maxMins, DateFormat fmt) {
    final dayIso = (rec['date'] ?? '').toString().split('T').first;
    String label = dayIso;
    try {
      label = fmt.format(DateTime.parse(dayIso));
    } catch (_) {}
    final mins = _mins(rec);
    final night = StudentScreenTimeController.toInt(
      rec['night_screen_time_minutes'] ?? rec['nightScreenTimeMinutes'] ?? rec['nightMinutes'] ?? rec['night'],
    );
    final selected = controller.effectiveSelectedDate == dayIso;
    final share = maxMins > 0 ? mins / maxMins : 0.0;

    return InkWell(
      onTap: () => controller.selectDate(dayIso),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: share.clamp(0.02, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: night > 0 ? AppColors.secondary : AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              child: Text(
                StudentScreenTimeController.formatMinutes(mins),
                textAlign: TextAlign.right,
                style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            SizedBox(
              width: 18,
              child: night > 0
                  ? const Icon(Icons.nightlight_round, size: 13, color: AppColors.cancelledRed)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  static int _mins(dynamic rec) => StudentScreenTimeController.toInt(
        rec['total_screen_time_minutes'] ?? rec['totalScreenTimeMinutes'] ?? rec['totalMinutes'] ?? rec['minutes'],
      );
}
