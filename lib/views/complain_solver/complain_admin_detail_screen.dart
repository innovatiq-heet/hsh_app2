import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/complaints/complaint_response.dart';
import '../../utils/date_formatting.dart';
import '../shared/utils/complaint_category_style.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_refresh_indicator.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/info_row.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/skeleton_loader.dart';
import '../shared/widgets/status_badge.dart';
import '../shared/widgets/stepper_timeline.dart';
import 'complain_admin_detail_controller.dart';

class ComplainAdminDetailScreen
    extends GetView<ComplainAdminDetailController> {
  const ComplainAdminDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.screenPadding),
                child: SkeletonList(),
              ),
            ),
          );
        }

        final c = controller.complaint.value;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Complaint Details')),
            body: const Center(child: Text('Complaint not found')),
          );
        }

        return AppRefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Hero Gradient Header
              GradientHeader(
                overline: 'Complaint #${c.id.toUpperCase()}',
                title: 'Complaint Review',
                subtitle: '${c.category} · Room ${c.room}',
                leading: Material(
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
                ),
                child: Row(
                  children: [
                    HeaderPill(
                      icon: Icons.calendar_today_rounded,
                      label:
                          'Submitted ${DateFormatting.dateOnly(c.submittedAt)}',
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    HeaderPill(
                      icon: Icons.meeting_room_outlined,
                      label: 'Room ${c.room}',
                    ),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapLg,
                  AppDimens.screenPadding,
                  60,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Resolution Timeline
                    const SectionHeader(title: 'Resolution progress'),
                    _StatusTimelineCard(complaint: c),
                    const SizedBox(height: AppDimens.gapXl),

                    // Section 2: Issue Summary
                    const SectionHeader(title: 'Issue summary'),
                    _IssueSummaryCard(complaint: c),
                    const SizedBox(height: AppDimens.gapXl),

                    // Section 3: Student Details
                    const SectionHeader(title: 'Student information'),
                    AppCard(
                      child: Column(
                        children: [
                          InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Student Name',
                            value: c.studentName,
                          ),
                          const Divider(height: AppDimens.gapLg),
                          InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Aadhar Number',
                            value: c.studentAadhar,
                          ),
                          const Divider(height: AppDimens.gapLg),
                          InfoRow(
                            icon: Icons.meeting_room_outlined,
                            label: 'Hostel Room',
                            value: 'Room ${c.room}',
                          ),
                          if (c.phone != null && c.phone!.isNotEmpty) ...[
                            const Divider(height: AppDimens.gapLg),
                            InfoRow(
                              icon: Icons.phone_outlined,
                              label: 'Contact Phone',
                              value: c.phone!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapXl),

                    // Section 4: Lifecycle Status Controls
                    const SectionHeader(title: 'Quick status change'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Current Stage',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select the current resolution state for this ticket.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          Wrap(
                            spacing: AppDimens.gapSm,
                            runSpacing: AppDimens.gapSm,
                            children: ComplaintStatus.values.map((s) {
                              final isSelected = c.status == s;
                              return ChoiceChip(
                                label: Text(s.label),
                                selected: isSelected,
                                selectedColor: s.color,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                onSelected: (_) => controller.setStatus(s),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapXl),

                    // Section 5: Staff Review / Assignment Note
                    const SectionHeader(title: 'Staff review & inspection note'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Internal Review / Assignee',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log technician details, inspection timings or internal instructions.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          AppTextField(
                            controller: controller.reviewController,
                            label: 'Staff Note / Assignee',
                            hint: 'e.g. Electrician Ramesh assigned. Visit at 4:30 PM.',
                            maxLines: 2,
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          AppButton(
                            label: 'Save Review Note',
                            icon: Icons.assignment_turned_in_outlined,
                            isLoading: controller.isSaving.value,
                            onPressed: controller.submitReviewNote,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapXl),

                    // Section 6: Resolution Feedback
                    const SectionHeader(title: 'Resolution explanation'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Closing Feedback to Student',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Explain how the issue was fixed. This will be visible to the student.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          AppTextField(
                            controller: controller.feedbackController,
                            label: 'Resolution Note',
                            hint: 'e.g. Replaced capacitor and cleaned motor. Tested fan speed.',
                            maxLines: 3,
                          ),
                          const SizedBox(height: AppDimens.gapMd),
                          AppButton(
                            label: 'Submit Resolution & Mark Closed',
                            icon: Icons.check_circle_outline_rounded,
                            isLoading: controller.isSaving.value,
                            onPressed: controller.submitFeedback,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatusTimelineCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _StatusTimelineCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stage Status',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              StatusBadge(
                label: complaint.status.label,
                color: complaint.status.color,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapLg),
          StepperTimeline(
            stages: [
              TimelineStage(
                label: 'Submitted',
                timestamp: complaint.submittedAt,
                isDone: true,
              ),
              TimelineStage(
                label: 'Under Review',
                timestamp: complaint.reviewTime,
                isDone: complaint.status == ComplaintStatus.reviewed ||
                    complaint.status == ComplaintStatus.resolved,
              ),
              TimelineStage(
                label: 'Resolved',
                timestamp: complaint.resolveTime,
                isDone: complaint.status == ComplaintStatus.resolved,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IssueSummaryCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _IssueSummaryCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final catStyle = ComplaintCategoryStyle.of(complaint.category);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: catStyle.icon, color: catStyle.color),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.title,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Category: ${complaint.category}',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppDimens.gapLg),
          Text(
            'Description',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            complaint.description,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          if (complaint.imagesCount > 0) ...[
            const SizedBox(height: AppDimens.gapMd),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${complaint.imagesCount} photo attachment${complaint.imagesCount > 1 ? 's' : ''} on record',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
