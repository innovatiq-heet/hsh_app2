import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../common_models/attachments/attachment_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../network/responses/complaints/complaint_response.dart';
import '../../utils/date_formatting.dart';
import '../shared/screens/image_gallery_viewer_screen.dart';
import '../shared/utils/complaint_category_style.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_refresh_indicator.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/info_row.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/skeleton_loader.dart';
import '../shared/widgets/status_badge.dart';
import '../shared/widgets/stepper_timeline.dart';
import 'complaint_detail_controller.dart';

class ComplaintDetailScreen extends GetView<ComplaintDetailController> {
  const ComplaintDetailScreen({super.key});

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
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Hero Gradient Header
              SliverGradientHeader(
                overline: 'Complaint #${c.id.toUpperCase()}',
                title: 'Complaint Details',
                subtitle: '${c.category} · Room ${c.room}',
                expandedHeight: 220.0,
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Get.back(),
                ),
                child: HeaderPill(
                  icon: Icons.calendar_today_rounded,
                  label: 'Submitted ${DateFormatting.dateOnly(c.submittedAt)}',
                ),
              ),

              // Content Body
              SliverToBoxAdapter(
                child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapXl,
                  AppDimens.screenPadding,
                  40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Resolution Progress Stepper
                    const SectionHeader(title: 'Resolution progress'),
                    _StatusTimelineCard(complaint: c),

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 2: Issue Description Card
                    const SectionHeader(title: 'Issue summary'),
                    _IssueSummaryCard(complaint: c),

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 3: Room & Student Details
                    const SectionHeader(title: 'Complaint details'),
                    _MetaDetailsCard(complaint: c),

                    // Section 4: Attachments (if available)
                    if (c.attachments.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.gapXl),
                      const SectionHeader(title: 'Attached evidence'),
                      _AttachmentsCard(attachments: c.attachments),
                    ],

                    // Section 5: Resolution Feedback (if available)
                    if (c.feedback != null && c.feedback!.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.gapXl),
                      const SectionHeader(title: 'Technician resolution'),
                      _ResolutionCard(feedback: c.feedback!),
                    ],

                    const SizedBox(height: AppDimens.gapXl),

                    // Section 6: Assistance Notice
                    _SupportNoticeCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      }),
    );
  }
}

/// Card with StepperTimeline showing Submitted -> Under Review -> Resolved
class _StatusTimelineCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _StatusTimelineCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final status = complaint.status;
    final isReviewed =
        status == ComplaintStatus.reviewed || status == ComplaintStatus.resolved;
    final isResolved = status == ComplaintStatus.resolved;

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Status', style: AppTextStyles.subtitle),
              StatusBadge(
                label: status.label,
                color: status.color,
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
                isDone: isReviewed,
              ),
              TimelineStage(
                label: 'Resolved',
                isDone: isResolved,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card showing the issue category, title, and formatted description box
class _IssueSummaryCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _IssueSummaryCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final style = ComplaintCategoryStyle.of(complaint.category);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category pill and complaint ID
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 14, color: style.color),
                    const SizedBox(width: 5),
                    Text(
                      complaint.category,
                      style: AppTextStyles.caption.copyWith(
                        color: style.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'ID: #${complaint.id.toUpperCase()}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.gapMd),

          // Title
          Text(complaint.title, style: AppTextStyles.headline),

          const SizedBox(height: AppDimens.gapSm),

          // Description box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.gapMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Text(
              complaint.description,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Metadata list card displaying Room, Student Name, and Submission timestamp
class _MetaDetailsCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _MetaDetailsCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding),
      child: Column(
        children: [
          InfoRow(
            icon: Icons.meeting_room_outlined,
            label: 'Room Number',
            value: complaint.room,
          ),
          const Divider(height: 1),
          InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Student Name',
            value: complaint.studentName,
          ),
          const Divider(height: 1),
          InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Submitted At',
            value: DateFormatting.dateTime(complaint.submittedAt),
          ),
        ],
      ),
    );
  }
}

/// Attached photos card with tap-to-view gallery preview
class _AttachmentsCard extends StatelessWidget {
  final List<AttachmentModel> attachments;

  const _AttachmentsCard({required this.attachments});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Attached Evidence (${attachments.length})',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              Text(
                'Tap to zoom',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: attachments.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppDimens.gapMd),
              itemBuilder: (context, i) {
                final a = attachments[i];
                return InkWell(
                  onTap: () => Get.to(
                    () => ImageGalleryViewerScreen(
                      attachments: attachments,
                      initialIndex: i,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMd - 1),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          a.isLocal
                              ? Image.file(
                                  a.file!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  a.url!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                ),
                          Container(
                            margin: const EdgeInsets.all(4),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.zoom_in_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolution feedback card shown when the complaint has technician notes
class _ResolutionCard extends StatelessWidget {
  final String feedback;

  const _ResolutionCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.successGreen.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.successGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppDimens.gapSm),
              Text(
                'Resolution Feedback',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(
            feedback,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(
            'Action taken by hostel maintenance team',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Support & hotline card
class _SupportNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.headset_mic_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimens.gapSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need urgent assistance?',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'For emergency issues (water overflow, short circuit), please report directly to the hostel warden desk.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
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
