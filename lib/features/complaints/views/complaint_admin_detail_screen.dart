import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/complaint_admin_detail_controller.dart';
import '../widgets/complaint_detail_cards.dart';

/// Solver/admin view of a complaint, with the status control.
class ComplainAdminDetailScreen extends GetView<ComplainAdminDetailController> {
  const ComplainAdminDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        // The back button lives in the sliver header, which an error hides.
        appBar: controller.hasError.value
            ? AppBar(title: const Text('Complaint Review'))
            : null,
        body: AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          loadingWidget: const SafeArea(child: SkeletonList()),
          builder: (context) => Obx(() {
            final c = controller.complaint.value!;
            return AppRefreshIndicator(
              onRefresh: () => controller.load(showLoading: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverGradientHeader(
                    overline: 'Complaint #${c.id}',
                    title: 'Complaint Review',
                    subtitle: '${c.category} · ${c.item}',
                    expandedHeight: 220.0,
                    leading: HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Get.back(),
                    ),
                    child: Row(
                      children: [
                        HeaderPill(
                          icon: Icons.calendar_today_rounded,
                          label: 'Submitted ${DateFormatting.dateOnly(c.createdAt)}',
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        HeaderPill(
                          icon: Icons.meeting_room_outlined,
                          label: 'Room ${c.roomId}',
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapLg,
                        AppDimens.screenPadding,
                        60,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(title: 'Update status'),
                          _StatusControlCard(complaint: c),
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Resolution progress'),
                          ComplaintTimelineCard(complaint: c),
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Issue summary'),
                          ComplaintIssueCard(complaint: c),
                          if (c.hasImage) ...[
                            const SizedBox(height: AppDimens.gapXl),
                            const SectionHeader(title: 'Attached photo'),
                            ComplaintPhotoCard(complaint: c),
                          ],
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Student information'),
                          _StudentCard(complaint: c),
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
    );
  }
}

/// One chip per status; any status may move to any other.
class _StatusControlCard extends GetView<ComplainAdminDetailController> {
  final ComplaintResponse complaint;

  const _StatusControlCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Obx(() => _card(controller.isSaving.value));
  }

  Widget _card(bool saving) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current stage',
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'The student sees the new status straight away.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.gapMd),
          Wrap(
            spacing: AppDimens.gapSm,
            runSpacing: AppDimens.gapSm,
            children: [
              for (final s in ComplaintStatus.values)
                ChoiceChip(
                  avatar: Icon(
                    s.icon,
                    size: 16,
                    color: complaint.status == s ? Colors.white : s.color,
                  ),
                  label: Text(s.staffLabel),
                  selected: complaint.status == s,
                  selectedColor: s.color,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: complaint.status == s
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: complaint.status == s
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  onSelected: saving ? null : (_) => controller.setStatus(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _StudentCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final student = complaint.student;
    return AppCard(
      child: Column(
        children: [
          InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Student Name',
            value: student?.name.isNotEmpty == true ? student!.name : '—',
          ),
          if (student != null && student.studentCode.isNotEmpty) ...[
            const Divider(height: AppDimens.gapLg),
            InfoRow(
              icon: Icons.badge_outlined,
              label: 'Student Code',
              value: student.studentCode,
            ),
          ],
          const Divider(height: AppDimens.gapLg),
          InfoRow(
            icon: Icons.meeting_room_outlined,
            label: 'Hostel Room',
            value: 'Room ${complaint.roomId}',
          ),
          const Divider(height: AppDimens.gapLg),
          InfoRow(
            icon: Icons.update_rounded,
            label: 'Last Updated',
            value: DateFormatting.dateTime(complaint.updatedAt),
          ),
        ],
      ),
    );
  }
}
