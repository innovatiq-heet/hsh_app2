import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/screen_time_utils.dart';
import 'student_detail_widget.dart';

/// The day picked on the calendar: its date, total screen time (with how much
/// of the daily limit that was) and the part of it that fell at night.
class SelectedDayCard extends StudentDetailWidget {
  const SelectedDayCard({super.key, required super.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final date = controller.effectiveSelectedDate;
      final parsed = DateTime.tryParse(date);
      final title = parsed == null ? date : DateFormat('EEEE, d MMMM').format(parsed);
      final total = controller.selectedDayTotalMinutes;
      final night = controller.selectedDayNightMinutes;
      final limit = controller.dailyLimitMinutes.value;
      final loading = controller.isLoadingDateUsage.value;
      final isToday = controller.isTodaySelected;
      final over = limit > 0 && total > limit;

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.title)),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    ),
                    child: Text(
                      'Today',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.gapMd),
            if (loading)
              const LinearProgressIndicator(minHeight: 3)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    total > 0 ? formatMinutes(total) : 'No usage',
                    style: AppTextStyles.displayMd.copyWith(
                      color: over ? AppColors.cancelledRed : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (limit > 0 && total > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        over
                            ? 'over the ${formatMinutes(limit)} limit'
                            : '${(total * 100 / limit).clamp(0, 100).round()}% of ${formatMinutes(limit)}',
                        style: AppTextStyles.bodySm.copyWith(
                          color: over ? AppColors.cancelledRed : AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            if (!loading && night > 0) ...[
              const SizedBox(height: AppDimens.gapSm),
              Row(
                children: [
                  const Icon(Icons.nightlight_round, size: 14, color: AppColors.cancelledRed),
                  const SizedBox(width: 6),
                  Text('${formatMinutes(night)} at night', style: AppTextStyles.bodySm),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
