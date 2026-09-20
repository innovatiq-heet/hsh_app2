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
      floatingActionButton: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            onTap: () => Get.toNamed(Routes.attendanceScanner),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Text(
                    'Scan QR Code',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) => RefreshIndicator(
            onRefresh: controller.load,
            child: CustomScrollView(
              slivers: [
                SliverGradientHeader(
                  overline: DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
                  title: 'Attendance',
                  subtitle: 'Daily routine & QR verification',
                  expandedHeight: 260.0,
                  leading: Navigator.canPop(context)
                      ? HeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onPressed: () => Get.back(),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapXl,
                      AppDimens.screenPadding,
                    110, // Generous clearance so FAB never obscures the last card
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
      final percent = ((marked / total) * 100).round();

      return Container(
        padding: const EdgeInsets.all(AppDimens.gapLg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: marked / total),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.20),
                      color: Colors.white,
                    ),
                  ),
                  Center(
                    child: Text(
                      '$marked/$total',
                      style: AppTextStyles.title.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
                  Row(
                    children: [
                      Text(
                        remaining == 0 ? 'All done for today' : "Today's progress",
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                        ),
                        child: Text(
                          '$percent%',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remaining == 0
                        ? 'All 5 daily sessions are attended! 🎉'
                        : '$remaining ${remaining == 1 ? 'session' : 'sessions'} remaining today',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
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

      return AppCard(
        onTap: () => Get.toNamed(
          Routes.attendanceScanner,
          arguments: type,
        ),
        color: isMarked
            ? AppColors.successGreen.withValues(alpha: 0.05)
            : AppColors.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.gapMd,
          vertical: AppDimens.gapMd,
        ),
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
                        style.emoji,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          type.label,
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                          : AppColors.textSecondary,
                      fontWeight: isMarked ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.gapSm),
            if (isMarked)
              const StatusBadge(
                label: 'Attended',
                color: AppColors.successGreen,
                icon: Icons.check_rounded,
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StatusBadge(
                    label: 'Pending',
                    color: AppColors.textMuted,
                    icon: Icons.schedule_rounded,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: style.softBackgroundColor,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 18,
                      color: style.primaryColor,
                    ),
                  ),
                ],
              ),
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
