import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/attendance/attendance_models.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'attendance_controller.dart';
import 'attendance_event_style.dart';

class AttendanceScreen extends GetView<AttendanceController> {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(
          'Scan QR Code',
          style: AppTextStyles.subtitle.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        onPressed: () => Get.toNamed(Routes.attendanceScanner),
      ),
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) => RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                GradientHeader(
                  overline: DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  title: 'Attendance',
                  subtitle: 'Daily routine & rotating QR verification',
                  leading: Navigator.canPop(context)
                      ? Material(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Get.back(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        )
                      : null,
                  actions: [
                    HeaderIconButton(
                      icon: Icons.history_rounded,
                      tooltip: 'History',
                      onPressed: () => Get.toNamed(Routes.attendanceHistory),
                    ),
                  ],
                  child: const _ProgressSummary(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapXl,
                    AppDimens.screenPadding,
                    AppDimens.gapXxl + 40, // Space for FAB
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: "Today's sessions"),
                      for (final type in AttendanceType.values)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimens.gapMd,
                          ),
                          child: _SessionCard(type: type),
                        ),
                      if (controller.upcomingSabhas.isNotEmpty) ...[
                        const SizedBox(height: AppDimens.gapLg),
                        const SectionHeader(title: 'Upcoming sabhas'),
                        for (final sabha in controller.upcomingSabhas)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.gapMd,
                            ),
                            child: _SabhaCard(sabha: sabha),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();
    return Obx(() {
      final total = AttendanceType.values.length;
      final marked = controller.todayStatus.values
          .where((v) => v != null)
          .length;
      final remaining = total - marked;

      return Container(
        padding: const EdgeInsets.all(AppDimens.gapLg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: marked / total),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      color: Colors.white,
                    ),
                  ),
                  Center(
                    child: Text(
                      '$marked/$total',
                      style: AppTextStyles.title.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.gapLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remaining == 0 ? 'All done for today' : "Today's progress",
                    style: AppTextStyles.title.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remaining == 0
                        ? 'All 5 daily sessions are attended.'
                        : '$remaining ${remaining == 1 ? 'session' : 'sessions'} remaining today',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SessionCard extends StatelessWidget {
  final AttendanceType type;

  const _SessionCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();
    final style = AttendanceEventStyle.of(type);

    return Obx(() {
      final markedAt = controller.todayStatus[type];
      final isMarked = markedAt != null;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isMarked
              ? AppColors.successGreen.withValues(alpha: 0.07)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isMarked
                ? AppColors.successGreen.withValues(alpha: 0.3)
                : AppColors.border,
          ),
          boxShadow: isMarked ? null : AppColors.softShadow,
        ),
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isMarked
                    ? AppColors.successGreen.withValues(alpha: 0.12)
                    : style.softBackgroundColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Icon(
                isMarked ? Icons.check_circle_rounded : style.icon,
                color: isMarked ? AppColors.successGreen : style.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${style.emoji} ${type.label}',
                        style: AppTextStyles.subtitle,
                      ),
                      const Spacer(),
                      StatusBadge(
                        label: isMarked ? 'Attended' : 'Pending',
                        color: isMarked
                            ? AppColors.successGreen
                            : AppColors.textMuted,
                        icon: isMarked
                            ? Icons.check_rounded
                            : Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isMarked
                        ? 'Attended at ${DateFormatting.time(markedAt)}'
                        : style.timingHint,
                    style: AppTextStyles.bodySm.copyWith(
                      color: isMarked
                          ? AppColors.successGreen
                          : AppColors.textMuted,
                      fontWeight: isMarked ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMarked) ...[
              const SizedBox(width: AppDimens.gapSm),
              IconButton.filledTonal(
                tooltip: 'Scan QR Code',
                style: IconButton.styleFrom(
                  backgroundColor: style.softBackgroundColor,
                  foregroundColor: style.primaryColor,
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                onPressed: () => Get.toNamed(Routes.attendanceScanner),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _SabhaCard extends StatelessWidget {
  final SabhaSession sabha;

  const _SabhaCard({required this.sabha});

  @override
  Widget build(BuildContext context) {
    final ist = DateFormatting.utcToIst(sabha.date);
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('d').format(ist),
                  style: AppTextStyles.headline.copyWith(color: Colors.white),
                ),
                Text(
                  DateFormat('MMM').format(ist).toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.gapLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sabha.description, style: AppTextStyles.subtitle),
                const SizedBox(height: AppDimens.gapXs),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: AppDimens.iconSm,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppDimens.gapXs),
                    Text(
                      '${DateFormatting.time(sabha.startTime)} – ${DateFormatting.time(sabha.endTime)}',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
