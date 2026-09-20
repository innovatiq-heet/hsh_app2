import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/leave_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/leave/leave_response.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'leave_controller.dart';

class LeaveScreen extends GetView<LeaveController> {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          builder: (context) => Obx(() {
            final allLeaves = controller.leaves;
            final filtered = controller.filteredLeaves;

            return RefreshIndicator(
              onRefresh: controller.load,
              child: CustomScrollView(
                slivers: [
                  SliverGradientHeader(
                    overline: 'Student Services',
                    title: 'Leave Requests',
                    subtitle: 'Apply for leave & track approval status',
                    expandedHeight: 250.0,
                    leading: Navigator.canPop(context)
                        ? HeaderIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: () => Get.back(),
                          )
                        : null,
                    child: _LeaveSummaryRow(controller: controller),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapXl,
                        AppDimens.screenPadding,
                        100,
                      ),
                    child: allLeaves.isEmpty
                        ? EmptyState(
                            icon: Icons.beach_access_outlined,
                            title: 'No leave requests yet',
                            message:
                                'Planning to travel or stay out? Submit a leave request for warden approval.',
                            actionLabel: 'Apply for Leave',
                            onAction: () => Get.toNamed(Routes.leaveAdd)
                                ?.then((_) => controller.load()),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FilterChips(controller: controller),
                              const SizedBox(height: AppDimens.gapLg),
                              SectionHeader(
                                title: controller.selectedFilter.value == null
                                    ? 'Request history'
                                    : '${controller.selectedFilter.value!.label} requests',
                              ),
                              if (filtered.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDimens.gapXl,
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: const BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.filter_list_off_rounded,
                                            size: 26,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: AppDimens.gapMd),
                                        Text(
                                          'No ${controller.selectedFilter.value!.label.toLowerCase()} requests found',
                                          style:
                                              AppTextStyles.subtitle.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: AppDimens.gapXs),
                                        TextButton(
                                          onPressed: () =>
                                              controller.setFilter(null),
                                          child:
                                              const Text('Show all requests'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                for (final leave in filtered)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppDimens.gapMd,
                                    ),
                                    child: _LeaveCard(
                                      leave: leave,
                                      canCancel: controller.canCancel(leave),
                                      onCancel: () =>
                                          _showCancelDialog(context, leave),
                                    ),
                                  ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
          }),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () =>
            Get.toNamed(Routes.leaveAdd)?.then((_) => controller.load()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply Leave'),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, LeaveResponse leave) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
        title: const Text('Cancel Request'),
        content: Text(
          'Are you sure you want to cancel this leave request from ${DateFormatting.dateOnly(leave.startTime)}?',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppDimens.gapLg,
          0,
          AppDimens.gapLg,
          AppDimens.gapLg,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Keep Request',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cancelledRed,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Get.back();
              controller.cancel(leave.id);
            },
            child: const Text('Cancel Leave'),
          ),
        ],
      ),
    );
  }
}

/// Header status summary showing count of Pending, Approved, and Rejected requests.
/// Tap any card to toggle filtering.
class _LeaveSummaryRow extends StatelessWidget {
  final LeaveController controller;

  const _LeaveSummaryRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final leaves = controller.leaves;
      final selected = controller.selectedFilter.value;

      return Row(
        children: [
          for (int i = 0; i < LeaveStatus.values.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.gapSm),
            Expanded(
              child: _StatusSummaryTile(
                status: LeaveStatus.values[i],
                count: leaves
                    .where((l) => l.status == LeaveStatus.values[i])
                    .length,
                isSelected: selected == LeaveStatus.values[i],
                onTap: () => controller.setFilter(LeaveStatus.values[i]),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _StatusSummaryTile extends StatelessWidget {
  final LeaveStatus status;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusSummaryTile({
    required this.status,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isSelected ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: Colors.white.withValues(alpha: isSelected ? 0.55 : 0.16),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: status.color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: AppTextStyles.displayMd.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal filter chips to quickly switch between All, Pending, Approved, and Rejected requests.
class _FilterChips extends StatelessWidget {
  final LeaveController controller;

  const _FilterChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedFilter.value;
      final allLeaves = controller.leaves;
      final pendingCount =
          allLeaves.where((l) => l.status == LeaveStatus.pending).length;
      final approvedCount =
          allLeaves.where((l) => l.status == LeaveStatus.approved).length;
      final rejectedCount =
          allLeaves.where((l) => l.status == LeaveStatus.rejected).length;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            _chip(
              label: 'All (${allLeaves.length})',
              isSelected: selected == null,
              onTap: () => controller.setFilter(null),
            ),
            const SizedBox(width: AppDimens.gapSm),
            _chip(
              label: 'Pending ($pendingCount)',
              isSelected: selected == LeaveStatus.pending,
              activeColor: AppColors.pendingBlue,
              onTap: () => controller.setFilter(LeaveStatus.pending),
            ),
            const SizedBox(width: AppDimens.gapSm),
            _chip(
              label: 'Approved ($approvedCount)',
              isSelected: selected == LeaveStatus.approved,
              activeColor: AppColors.successGreen,
              onTap: () => controller.setFilter(LeaveStatus.approved),
            ),
            const SizedBox(width: AppDimens.gapSm),
            _chip(
              label: 'Rejected ($rejectedCount)',
              isSelected: selected == LeaveStatus.rejected,
              activeColor: AppColors.cancelledRed,
              onTap: () => controller.setFilter(LeaveStatus.rejected),
            ),
          ],
        ),
      );
    });
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
}

/// Rich, clean card presenting a single leave request.
class _LeaveCard extends StatelessWidget {
  final LeaveResponse leave;
  final bool canCancel;
  final VoidCallback onCancel;

  const _LeaveCard({
    required this.leave,
    required this.canCancel,
    required this.onCancel,
  });

  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final days = (diff.inHours / 24).ceil();
    if (days <= 1) {
      if (diff.inHours > 0 && diff.inHours < 24) {
        return '${diff.inHours}h Outing';
      }
      return '1 Day';
    }
    return '$days Days';
  }

  IconData _statusIcon(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.pending:
        return Icons.hourglass_top_rounded;
      case LeaveStatus.approved:
        return Icons.check_circle_rounded;
      case LeaveStatus.rejected:
        return Icons.highlight_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Duration pill and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDuration(leave.startTime, leave.endTime),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: leave.status.label,
                color: leave.status.color,
                icon: _statusIcon(leave.status),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.gapMd),

          // Date Journey Container
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.gapMd,
              vertical: AppDimens.gapMd,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                // Departure column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEPARTURE',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          DateFormatting.dateOnly(leave.startTime),
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatting.time(leave.startTime),
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow connector
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.gapSm,
                  ),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                // Return column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RETURN',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          DateFormatting.dateOnly(leave.endTime),
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatting.time(leave.endTime),
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.gapMd),

          // Reason Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppDimens.gapSm),
              Expanded(
                child: Text(
                  leave.reason,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.gapMd),
          const Divider(height: 1),
          const SizedBox(height: AppDimens.gapSm),

          // Bottom Bar: Applied timestamp & optional Cancel button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_toggle_off_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Applied ${DateFormatting.dateOnly(leave.appliedAt)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (canCancel)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.cancelledRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Cancel',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.cancelledRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
