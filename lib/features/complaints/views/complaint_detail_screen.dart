import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import '../controllers/complaint_detail_controller.dart';
import '../widgets/complaint_detail_cards.dart';

/// A student's own complaint. Read-only: only solvers change the status.
class ComplaintDetailScreen extends GetView<ComplaintDetailController> {
  const ComplaintDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        // The back button lives in the sliver header, which an error hides.
        appBar: controller.hasError.value
            ? AppBar(title: const Text('Complaint Details'))
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
                    title: 'Complaint Details',
                    subtitle: '${c.category} · ${c.item}',
                    expandedHeight: 220.0,
                    leading: HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Get.back(),
                    ),
                    child: HeaderPill(
                      icon: Icons.calendar_today_rounded,
                      label: 'Submitted ${DateFormatting.dateOnly(c.createdAt)}',
                    ),
                  ),
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
                          const SectionHeader(title: 'Resolution progress'),
                          ComplaintTimelineCard(complaint: c),
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Issue summary'),
                          ComplaintIssueCard(complaint: c),
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Complaint details'),
                          _MetaDetailsCard(complaint: c),
                          if (c.hasImage) ...[
                            const SizedBox(height: AppDimens.gapXl),
                            const SectionHeader(title: 'Attached photo'),
                            ComplaintPhotoCard(complaint: c),
                          ],
                          const SizedBox(height: AppDimens.gapXl),
                          const _SupportNoticeCard(),
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
            value: complaint.roomId,
          ),
          const Divider(height: 1),
          InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Submitted At',
            value: DateFormatting.dateTime(complaint.createdAt),
          ),
          const Divider(height: 1),
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

class _SupportNoticeCard extends StatelessWidget {
  const _SupportNoticeCard();

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
