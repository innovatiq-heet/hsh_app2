import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/complaints/complaint_response.dart';
import '../../storage/session_store.dart';
import '../../utils/date_formatting.dart';
import '../shared/utils/complaint_category_style.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_refresh_indicator.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/status_badge.dart';
import 'complain_orders_controller.dart';

class ComplainOrdersScreen extends GetView<ComplainOrdersController> {
  const ComplainOrdersScreen({super.key});

  Future<void> _logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AsyncStateView(
        isLoading: controller.isLoading.value,
        hasError: controller.hasError.value,
        errorMessage: controller.errorMessage.value,
        onRetry: controller.load,
        builder: (context) {
          final list = controller.filtered;
          return AppRefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Hero Gradient Header
                GradientHeader(
                  overline: 'Staff Operations',
                  title: 'Complaints Desk',
                  subtitle: 'Review reports, assign maintenance & resolve issues',
                  actions: [
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh',
                      onPressed: controller.load,
                    ),
                    HeaderIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Log out',
                      onPressed: _logout,
                    ),
                  ],
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        HeaderPill(
                          icon: Icons.hourglass_top_rounded,
                          label: '${controller.pendingCount} Pending',
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        HeaderPill(
                          icon: Icons.sync_rounded,
                          label: '${controller.reviewedCount} Under Review',
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        HeaderPill(
                          icon: Icons.check_circle_rounded,
                          label: '${controller.resolvedCount} Resolved',
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapLg,
                    AppDimens.screenPadding,
                    100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search & Quick Filter Card
                      AppCard(
                        padding: const EdgeInsets.all(AppDimens.gapMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: 'Search Complaints',
                              hint: 'Search by room, name, category, title or ID...',
                              prefixIcon: Icons.search_rounded,
                              onChanged: (val) =>
                                  controller.searchQuery.value = val,
                            ),
                            const SizedBox(height: AppDimens.gapMd),

                            // Status Filter Chips
                            Text(
                              'Status Filter',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: AppDimens.gapXs),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'All',
                                    count: controller.complaints.length,
                                    isSelected:
                                        controller.statusFilter.value == null,
                                    onSelected: () =>
                                        controller.statusFilter.value = null,
                                  ),
                                  const SizedBox(width: AppDimens.gapSm),
                                  ...ComplaintStatus.values.map(
                                    (status) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppDimens.gapSm,
                                      ),
                                      child: _FilterChip(
                                        label: status.label,
                                        count:
                                            controller.countForStatus(status),
                                        isSelected:
                                            controller.statusFilter.value ==
                                                status,
                                        statusColor: status.color,
                                        onSelected: () =>
                                            controller.statusFilter.value =
                                                status,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimens.gapMd),

                            // Category Filter Chips
                            Text(
                              'Category Filter',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: AppDimens.gapXs),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _CategoryChip(
                                    label: 'All Categories',
                                    isSelected:
                                        controller.categoryFilter.value == null,
                                    onSelected: () =>
                                        controller.categoryFilter.value = null,
                                  ),
                                  const SizedBox(width: AppDimens.gapSm),
                                  ...[
                                    'Electrical',
                                    'Plumbing',
                                    'Furniture',
                                    'Housekeeping',
                                    'Internet/Wifi',
                                    'Other'
                                  ].map(
                                    (cat) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppDimens.gapSm,
                                      ),
                                      child: _CategoryChip(
                                        label: cat,
                                        count: controller.countForCategory(cat),
                                        isSelected:
                                            controller.categoryFilter.value
                                                    ?.toLowerCase() ==
                                                cat.toLowerCase(),
                                        onSelected: () {
                                          if (controller.categoryFilter.value
                                                  ?.toLowerCase() ==
                                              cat.toLowerCase()) {
                                            controller.categoryFilter.value = null;
                                          } else {
                                            controller.categoryFilter.value = cat;
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapLg),

                      // Section Header with count
                      SectionHeader(
                        title: controller.statusFilter.value == null
                            ? 'All Complaints (${list.length})'
                            : '${controller.statusFilter.value!.label} Complaints (${list.length})',
                      ),
                      const SizedBox(height: AppDimens.gapSm),

                      // Complaints List
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: EmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'No complaints found',
                            message: controller.searchQuery.value.isNotEmpty ||
                                    controller.statusFilter.value != null ||
                                    controller.categoryFilter.value != null
                                ? 'No complaints match your current filters. Try resetting search or filter chips.'
                                : 'There are currently no maintenance complaints in the system.',
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppDimens.gapMd),
                          itemBuilder: (context, i) {
                            final c = list[i];
                            return _StaffComplaintCard(
                              complaint: c,
                              controller: controller,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? statusColor;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onSelected,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isSelected ? AppColors.primary : AppColors.surfaceMuted;
    final activeText = isSelected ? Colors.white : AppColors.textPrimary;
    final countBg = isSelected
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.border;

    return Material(
      color: activeBg,
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: activeText,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: activeText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        count != null ? '$label ($count)' : label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.secondary,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}

class _StaffComplaintCard extends StatelessWidget {
  final ComplaintResponse complaint;
  final ComplainOrdersController controller;

  const _StaffComplaintCard({
    required this.complaint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final catStyle = ComplaintCategoryStyle.of(complaint.category);

    return AppCard(
      onTap: () => Get.toNamed(
        Routes.complainAdminDetail,
        arguments: complaint.id,
      )?.then((_) => controller.load()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon Badge
              IconBadge(
                icon: catStyle.icon,
                color: catStyle.color,
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            complaint.studentName.isNotEmpty
                                ? complaint.studentName
                                : 'Student #${complaint.studentAadhar}',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (complaint.room.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.meeting_room_outlined,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  complaint.room,
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Complaint #${complaint.id.toUpperCase()}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (complaint.studentAadhar.isNotEmpty) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          Text(
                            complaint.studentAadhar,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: complaint.status.label,
                color: complaint.status.color,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),

          // Title & Description
          Text(
            complaint.title,
            style: AppTextStyles.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            complaint.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),

          // Category pill & photos indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catStyle.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  complaint.category,
                  style: AppTextStyles.caption.copyWith(
                    color: catStyle.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (complaint.imagesCount > 0) ...[
                const SizedBox(width: AppDimens.gapSm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${complaint.imagesCount} photo${complaint.imagesCount > 1 ? 's' : ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                DateFormatting.dateTime(complaint.submittedAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          // Staff review note if present
          if (complaint.review != null && complaint.review!.isNotEmpty) ...[
            const SizedBox(height: AppDimens.gapSm),
            Container(
              padding: const EdgeInsets.all(AppDimens.gapSm + 2),
              decoration: BoxDecoration(
                color: AppColors.pendingBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                  color: AppColors.pendingBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_ind_outlined,
                    size: 16,
                    color: AppColors.pendingBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Review note: ${complaint.review}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Resolution note if present
          if (complaint.feedback != null && complaint.feedback!.isNotEmpty) ...[
            const SizedBox(height: AppDimens.gapSm),
            Container(
              padding: const EdgeInsets.all(AppDimens.gapSm + 2),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Resolution: ${complaint.feedback}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: AppDimens.gapLg),

          // Actions Row based on Lifecycle
          Obx(() {
            final isAdvancing =
                controller.advancingComplaintId.value == complaint.id;
            if (isAdvancing) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _buildLifecycleButton(context),
                ),
                if (controller.isAdmin.value) ...[
                  const SizedBox(width: AppDimens.gapSm),
                  IconButton(
                    tooltip: 'Delete Complaint',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.cancelledRed,
                    ),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLifecycleButton(BuildContext context) {
    switch (complaint.status) {
      case ComplaintStatus.pending:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Mark Review',
                icon: Icons.sync_rounded,
                onPressed: () => _showReviewSheet(context),
              ),
            ),
            const SizedBox(width: AppDimens.gapSm),
            Expanded(
              child: AppButton(
                label: 'Quick Resolve',
                icon: Icons.check_circle_outline_rounded,
                variant: AppButtonVariant.outline,
                onPressed: () => _showResolveSheet(context),
              ),
            ),
          ],
        );
      case ComplaintStatus.reviewed:
        return AppButton(
          label: 'Resolve & Close Issue',
          icon: Icons.done_all_rounded,
          onPressed: () => _showResolveSheet(context),
        );
      case ComplaintStatus.resolved:
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: AppColors.successGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resolved & Closed',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppDimens.gapSm),
            AppButton(
              label: 'Update',
              icon: Icons.edit_note_rounded,
              variant: AppButtonVariant.outline,
              onPressed: () => _showResolveSheet(context),
            ),
          ],
        );
    }
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Complaint'),
        content: Text(
          'Are you sure you want to delete complaint #${complaint.id}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.cancelledRed),
            onPressed: () {
              Get.back();
              controller.deleteComplaint(complaint.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReviewSheet(BuildContext context) {
    final noteController = TextEditingController(text: complaint.review ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapLg,
          AppDimens.screenPadding,
          MediaQuery.of(context).viewInsets.bottom + AppDimens.gapXl,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            Text(
              'Move to Under Review',
              style: AppTextStyles.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Assign maintenance staff or add an internal inspection remark for Room ${complaint.room}.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppTextField(
              controller: noteController,
              label: 'Review Note / Assigned Technician',
              hint: 'e.g. Electrician Ramesh assigned. Visit at 4:30 PM.',
              maxLines: 3,
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppButton(
              label: 'Confirm Under Review',
              icon: Icons.check_circle_rounded,
              onPressed: () {
                Get.back();
                controller.markReviewed(
                  complaint.id,
                  reviewNote: noteController.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResolveSheet(BuildContext context) {
    final noteController = TextEditingController(text: complaint.feedback ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapLg,
          AppDimens.screenPadding,
          MediaQuery.of(context).viewInsets.bottom + AppDimens.gapXl,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            Text(
              'Resolve Complaint #${complaint.id.toUpperCase()}',
              style: AppTextStyles.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Provide feedback explaining how the issue was resolved for the student.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppTextField(
              controller: noteController,
              label: 'Resolution Explanation',
              hint: 'e.g. Replaced leaking valve and tested pressure.',
              maxLines: 3,
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppButton(
              label: 'Submit Resolution & Close',
              icon: Icons.done_all_rounded,
              onPressed: () {
                if (noteController.text.trim().isEmpty) {
                  Get.snackbar(
                    'Input Required',
                    'Please describe the resolution before closing the complaint.',
                  );
                  return;
                }
                Get.back();
                controller.markResolved(
                  complaint.id,
                  feedback: noteController.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
