import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final topPadding = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Obx(
        () => Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
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
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ComplaintAdminDetailHeaderDelegate(
                        complaint: c,
                        topPadding: topPadding,
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
      ),
    );
  }
}

/// Collapsible deep-navy header matching Complaints Desk and Overview.
class _ComplaintAdminDetailHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final ComplaintResponse complaint;
  final double topPadding;

  const _ComplaintAdminDetailHeaderDelegate({
    required this.complaint,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent => topPadding + 195.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius =
        Radius.circular((34.0 * (1.0 - progress)).clamp(0.0, 34.0));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF03192E),
            Color(0xFF032B4F),
            Color(0xFF025A8D),
            Color(0xFF0369A1),
          ],
          stops: [0.0, 0.38, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        boxShadow: progress > 0.25
            ? [
                BoxShadow(
                  color: const Color(0xFF03192E)
                      .withValues(alpha: 0.22 * progress),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ambient decorative orbs
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Top Nav Row
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: Text(
                        'Complaint #${complaint.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: complaint.status.color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: complaint.status.color.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          complaint.status.icon,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          complaint.status.staffLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expanded header content
            if (expandedOpacity > 0.01)
              Positioned(
                top: topPadding + 54,
                left: 20,
                right: 20,
                bottom: 12,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 28,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAAB78),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'COMPLAINT #${complaint.id}',
                        style: const TextStyle(
                          color: Color(0xB8FFFFFF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Complaint Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${complaint.category} · ${complaint.item}',
                        style: const TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _headerPill(
                              icon: Icons.calendar_today_rounded,
                              label:
                                  'Submitted ${DateFormatting.dateOnly(complaint.createdAt)}',
                            ),
                            const SizedBox(width: 8),
                            _headerPill(
                              icon: Icons.meeting_room_outlined,
                              label: 'Room ${complaint.roomId}',
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
    );
  }

  Widget _headerPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(
    covariant _ComplaintAdminDetailHeaderDelegate oldDelegate,
  ) =>
      oldDelegate.complaint != complaint;
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
