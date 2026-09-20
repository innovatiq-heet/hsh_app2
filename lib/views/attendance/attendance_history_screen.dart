import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/status_badge.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import '../../network/responses/attendance/attendance_models.dart';
import 'attendance_event_style.dart';
import 'attendance_history_controller.dart';

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
                            padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
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

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.softBackgroundColor,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Icon(
              style.icon,
              color: style.primaryColor,
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
                      '${style.emoji} ${entry.type.label}',
                      style: AppTextStyles.subtitle,
                    ),
                    const Spacer(),
                    StatusBadge(
                      label: entry.viaCode ? 'QR Verified' : 'Logged',
                      color: entry.viaCode
                          ? AppColors.successGreen
                          : AppColors.primary,
                      icon: entry.viaCode
                          ? Icons.qr_code_2_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapXs),
                Text(
                  DateFormatting.dateTime(entry.time),
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

