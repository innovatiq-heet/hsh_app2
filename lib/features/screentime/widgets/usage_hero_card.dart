import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/animated_counter.dart';
import '../controllers/screen_time_utils.dart';
import '../curfew/curfew_schedule.dart';
import 'student_detail_widget.dart';

/// The headline number for the selected day, with the daily allowance and
/// curfew usage shown against it so the warden sees "how much" *and* "vs what".
class UsageHeroCard extends StudentDetailWidget {
  const UsageHeroCard({super.key, required super.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isToday = controller.isTodaySelected;
      final total = controller.selectedDayTotalMinutes;
      final night = controller.selectedDayNightMinutes;
      final limit = controller.dailyLimitMinutes.value;
      final progress = controller.limitProgress;
      final overLimit = limit > 0 && total >= limit;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: isToday
              ? AppColors.heroGradient
              : const LinearGradient(
                  colors: [AppColors.accentDark, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dayTitle(isToday),
                    style: AppTextStyles.overline.copyWith(color: Colors.white70),
                  ),
                ),
                if (overLimit)
                  _pill('Over limit', Icons.hourglass_disabled_rounded, const Color(0xFFFFCDD2))
                else if (isToday)
                  _pill('Live', Icons.sensors_rounded, Colors.white),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedCounter(
                  value: total ~/ 60,
                  style: AppTextStyles.displayXl.copyWith(color: Colors.white, fontSize: 34, height: 1),
                ),
                Text('h  ', style: AppTextStyles.subtitle.copyWith(color: Colors.white70)),
                AnimatedCounter(
                  value: total % 60,
                  style: AppTextStyles.displayXl.copyWith(color: Colors.white, fontSize: 34, height: 1),
                ),
                Text('m', style: AppTextStyles.subtitle.copyWith(color: Colors.white70)),
                const Spacer(),
                Text(
                  limit > 0 ? '${formatMinutes(total)} / ${formatMinutes(limit)}' : 'No daily limit',
                  style: AppTextStyles.caption.copyWith(
                    color: limit > 0 ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (limit > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(
                      overLimit ? const Color(0xFFFF8A80) : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            if (night > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.nightlight_round, color: Color(0xFFFFCC80), size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${formatMinutes(night)} used during curfew'
                        '${controller.bedtimeStart.value.isEmpty ? '' : ' (${controller.bedtimeStart.value}–${controller.bedtimeEnd.value})'}',
                        style: AppTextStyles.caption.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  String _dayTitle(bool isToday) {
    if (isToday) return 'SCREEN TIME TODAY';
    try {
      final parsed = DateTime.parse(controller.effectiveSelectedDate);
      final yest = istNow().subtract(const Duration(days: 1));
      if (parsed.year == yest.year && parsed.month == yest.month && parsed.day == yest.day) {
        return 'SCREEN TIME YESTERDAY';
      }
      return DateFormat('EEE, d MMM').format(parsed).toUpperCase();
    } catch (_) {
      return 'SCREEN TIME';
    }
  }

  Widget _pill(String text, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(text, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
