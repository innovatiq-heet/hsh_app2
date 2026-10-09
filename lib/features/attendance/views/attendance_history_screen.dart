import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/attendance_type.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../../core/network/responses/attendance/attendance_models.dart';
import 'attendance_event_style.dart';
import '../controllers/attendance_history_controller.dart';

class AttendanceHistoryScreen extends GetView<AttendanceHistoryController> {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  overline: 'Student Services',
                  title: 'Attendance History',
                  subtitle: 'Review marked sessions & verification logs',
                  expandedHeight: 220.0,
                  leading: Navigator.canPop(context)
                      ? HeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onPressed: () => Get.back(),
                        )
                      : null,
                  actions: [
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh',
                      onPressed: controller.load,
                    ),
                  ],
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        HeaderPill(
                          icon: Icons.history_rounded,
                          label: '${controller.entries.length} Sessions Logged',
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapXl,
                      AppDimens.screenPadding,
                      AppDimens.gapXxl,
                    ),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(
                          () => Row(
                            children: [
                              _chip(
                                label: 'All Sessions',
                                isSelected: controller.typeFilter.value == null,
                                onTap: () => controller.setTypeFilter(null),
                              ),
                              const SizedBox(width: AppDimens.gapSm),
                              ...AttendanceType.values.map((t) {
                                final style = AttendanceEventStyle.of(t);
                                return Padding(
                                  padding: const EdgeInsets.only(right: AppDimens.gapSm),
                                  child: _chip(
                                    label: '${style.emoji} ${t.label}',
                                    isSelected: controller.typeFilter.value == t,
                                    activeColor: style.primaryColor,
                                    onTap: () => controller.setTypeFilter(t),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      Obx(
                        () => Row(
                          children: [
                            ActionChip(
                              avatar: const Icon(
                                Icons.calendar_month_outlined,
                                size: AppDimens.iconSm,
                              ),
                              label: Text(
                                controller.fromDate.value == null
                                    ? 'Filter by Date'
                                    : '${DateFormatting.dateOnly(controller.fromDate.value!)} – ${controller.toDate.value != null ? DateFormatting.dateOnly(controller.toDate.value!) : 'Today'}',
                                style: AppTextStyles.label,
                              ),
                              onPressed: () => _pickRange(context),
                            ),
                            if (controller.typeFilter.value != null ||
                                controller.fromDate.value != null) ...[
                              const SizedBox(width: AppDimens.gapSm),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.close_rounded,
                                  size: AppDimens.iconSm,
                                ),
                                label: Text('Clear', style: AppTextStyles.label),
                                onPressed: controller.clearFilters,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapLg),
                      Obx(
                        () => SectionHeader(
                          title: controller.typeFilter.value == null
                              ? 'All records'
                              : '${controller.typeFilter.value!.label} records',
                        ),
                      ),
                      if (controller.entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppDimens.gapXl),
                          child: EmptyState(
                            icon: Icons.event_busy_outlined,
                            title: 'No attendance logs found',
                            message: 'There are no attendance records matching your selected filters.',
                            actionLabel: 'Show all records',
                            onAction: controller.clearFilters,
                          ),
                        )
                      else
                        for (final entry in controller.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
                            child: _HistoryCard(entry: entry),
                          ),
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

  Widget _chip({
    required String label,
    required bool isSelected,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final color = activeColor ?? AppColors.primary;
    return Material(
      color: isSelected ? color : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? color : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (range != null) {
      controller.setDateRange(range.start, range.end);
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final AttendanceRecord entry;

  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final style = AttendanceEventStyle.of(entry.type);
    final dateStr = DateFormat('dd MMM yyyy').format(entry.date);
    final timeStr = DateFormat('hh:mm a').format(entry.time.toLocal());

    // Status indicator color (Default to Present/Success Green for marked records)
    final Color statusColor = AppColors.successGreen;
    final String methodLabel = entry.viaCode ? 'Dynamic QR' : 'BLE Proximity';
    final IconData methodIcon = entry.viaCode ? Icons.qr_code_2_rounded : Icons.bluetooth_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left edge status color indicator
              Container(
                width: 5,
                color: statusColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Event icon badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: style.softBackgroundColor,
                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        ),
                        child: Icon(
                          style.icon,
                          color: style.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${style.emoji} ${entry.type.label}',
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                StatusBadge(
                                  label: 'Present',
                                  color: statusColor,
                                  icon: Icons.check_circle_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$dateStr • $timeStr',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Method Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(methodIcon, size: 11, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        methodLabel,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Location Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Floor Gate Verified',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

