import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/utils/complaint_category_style.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/complaints_controller.dart';

class ComplaintsScreen extends GetView<ComplaintsController> {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          loadingWidget: const _ComplaintsShimmer(),
          builder: (context) => AppRefreshIndicator(
            onRefresh: controller.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverGradientHeader(
                  overline: 'Help desk',
                  title: 'Complaints',
                  subtitle: 'Report and track issues in your room',
                  expandedHeight: 280.0,
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
                  child: _StatusSummary(complaints: controller.complaints),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapXl,
                      AppDimens.screenPadding,
                      100,
                    ),
                    child: controller.complaints.isEmpty
                        ? const EmptyState(
                            icon: Icons.support_agent_outlined,
                            title: 'No complaints yet',
                            message:
                                'Something not working? Raise a complaint and the maintenance team will pick it up.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SectionHeader(title: 'Your complaints'),
                              for (int i = 0; i < controller.complaints.length; i++)
                                StaggeredSlideFade(
                                  index: i,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppDimens.gapMd,
                                    ),
                                    child: _ComplaintCard(
                                      complaint: controller.complaints[i],
                                    ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () =>
            Get.toNamed(Routes.complaintAdd)?.then((_) => controller.load()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New complaint'),
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  final List<ComplaintResponse> complaints;

  const _StatusSummary({required this.complaints});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < ComplaintStatus.values.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.gapSm),
          Expanded(child: _countTile(ComplaintStatus.values[i])),
        ],
      ],
    );
  }

  Widget _countTile(ComplaintStatus status) {
    final count = complaints.where((c) => c.status == status).length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: AppTextStyles.displayMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final style = ComplaintCategoryStyle.of(complaint.category);
    return AppCard(
      onTap: () => Get.toNamed(Routes.complaintDetail, arguments: complaint.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: style.icon, color: style.color),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(complaint.title, style: AppTextStyles.subtitle),
                    const SizedBox(height: 2),
                    Text(
                      '${complaint.category} · ${DateFormatting.dateOnly(complaint.submittedAt)}',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: complaint.status.label,
                color: complaint.status.color,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(
            complaint.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintsShimmer extends StatelessWidget {
  const _ComplaintsShimmer();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverGradientHeader(
          overline: 'Help desk',
          title: 'Complaints',
          subtitle: 'Report and track issues in your room',
          expandedHeight: 280.0,
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
              onPressed: () {},
            ),
          ],
          child: Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppDimens.gapSm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                          height: 28,
                          width: 32,
                          borderRadius: BorderRadius.circular(4),
                          baseColor: Colors.white.withValues(alpha: 0.16),
                          highlightColor: Colors.white.withValues(alpha: 0.38),
                        ),
                        const SizedBox(height: 6),
                        SkeletonLoader(
                          height: 12,
                          width: 52,
                          borderRadius: BorderRadius.circular(3),
                          baseColor: Colors.white.withValues(alpha: 0.12),
                          highlightColor: Colors.white.withValues(alpha: 0.28),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.gapXl,
              AppDimens.screenPadding,
              100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SkeletonLoader(
                      height: 18,
                      width: 130,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapMd),
                for (int i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppDimens.gapMd),
                    child: _ComplaintCardShimmer(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComplaintCardShimmer extends StatelessWidget {
  const _ComplaintCardShimmer();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonLoader(
                height: 44,
                width: 44,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                      height: 16,
                      width: 140,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    SkeletonLoader(
                      height: 12,
                      width: 96,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.gapSm),
              SkeletonLoader(
                height: 24,
                width: 66,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          SkeletonLoader(
            height: 13,
            width: double.infinity,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 6),
          const SkeletonLoader(
            height: 13,
            width: 200,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ],
      ),
    );
  }
}
