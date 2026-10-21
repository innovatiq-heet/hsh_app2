import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/chart_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/complaint_home_controller.dart';

class ComplainHomeScreen extends GetView<ComplainHomeController> {
  const ComplainHomeScreen({super.key});

  Future<void> _logout() async {
    await Get.find<SessionStore>().clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final canPop = Navigator.canPop(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Obx(
          () => AsyncStateView(
            isLoading: controller.isLoading.value,
            hasError: controller.hasError.value,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.load,
            loadingWidget: _ComplainHomeShimmer(topPadding: topPadding),
            builder: (context) => Obx(
              () => AppRefreshIndicator(
                onRefresh: () => controller.load(showLoading: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Signature Deep-Navy Collapsing Header
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ComplaintsHomeHeaderDelegate(
                        controller: controller,
                        topPadding: topPadding,
                        canPop: canPop,
                        onLogout: _logout,
                      ),
                    ),

                    // Body Content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimens.screenPadding,
                          AppDimens.gapLg,
                          AppDimens.screenPadding,
                          100,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Volume Summary Card
                            AppCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0369A1)
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.assignment_outlined,
                                                size: 16,
                                                color: Color(0xFF0369A1),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                controller.isCapped.value
                                                    ? 'Latest Complaints'
                                                    : 'Total Complaints',
                                                style: AppTextStyles.bodySm
                                                    .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${controller.totalComplaints.value}',
                                          style: AppTextStyles.displayLg
                                              .copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 52,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: AppDimens.gapMd,
                                    ),
                                    color: AppColors.border,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF16A34A)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.trending_up_rounded,
                                                size: 16,
                                                color: Color(0xFF16A34A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Resolution Rate',
                                                style: AppTextStyles.bodySm
                                                    .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${controller.resolutionRate.value.toStringAsFixed(0)}%',
                                          style: AppTextStyles.displayLg
                                              .copyWith(
                                            color: const Color(0xFF16A34A),
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (controller.isCapped.value) ...[
                              const SizedBox(height: AppDimens.gapXs),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  'Figures cover the latest ${ComplainHomeController.sampleSize} complaints.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppDimens.gapXl),

                            // 4 Status Cards Grid
                            const SectionHeader(title: 'Queue Breakdown'),
                            const SizedBox(height: AppDimens.gapSm),
                            for (final row in [
                              [ComplaintStatus.open, ComplaintStatus.inProgress],
                              [ComplaintStatus.resolved, ComplaintStatus.closed],
                            ]) ...[
                              if (row.first != ComplaintStatus.open)
                                const SizedBox(height: AppDimens.gapMd),
                              Row(
                                children: [
                                  for (final status in row) ...[
                                    if (status != row.first)
                                      const SizedBox(width: AppDimens.gapMd),
                                    Expanded(
                                      child: _StatusStatCard(
                                        title: status.staffLabel,
                                        count: controller.countOf(status),
                                        color: status.color,
                                        icon: status.icon,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            const SizedBox(height: AppDimens.gapXl),

                            // Category Breakdown Chart
                            const SectionHeader(title: 'Category Distribution'),
                            const SizedBox(height: AppDimens.gapSm),
                            ChartCard(
                              title: 'Complaints by Category',
                              points: controller.categoryCounts,
                              barColor: const Color(0xFF0369A1),
                            ),
                            const SizedBox(height: AppDimens.gapLg),

                            // Status Breakdown Chart
                            const SectionHeader(title: 'Status Distribution'),
                            const SizedBox(height: AppDimens.gapSm),
                            ChartCard(
                              title: 'Complaints by Status',
                              points: controller.statusCounts,
                              barColor: const Color(0xFF0284C7),
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
        ),
      ),
    );
  }
}

/// Collapsible deep-navy header matching Screen Time, Geofence & Complaints Desk.
class _ComplaintsHomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ComplainHomeController controller;
  final double topPadding;
  final bool canPop;
  final Future<void> Function() onLogout;

  const _ComplaintsHomeHeaderDelegate({
    required this.controller,
    required this.topPadding,
    required this.canPop,
    required this.onLogout,
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

    return Obx(() {
      final active = controller.activeCount;
      final rate = controller.resolutionRate.value.toStringAsFixed(0);

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

              // Top Nav Bar
              Positioned(
                top: topPadding + 6,
                left: 16,
                right: 16,
                height: 46,
                child: Row(
                  children: [
                    if (canPop)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
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
                      )
                    else
                      Container(
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
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Opacity(
                        opacity: collapsedTitleOpacity,
                        child: const Text(
                          'Complaints Overview',
                          style: TextStyle(
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
                    // Action: Refresh
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: controller.load,
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
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action: Logout
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onLogout,
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
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
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
                        const Text(
                          'PERFORMANCE & ANALYTICS',
                          style: TextStyle(
                            color: Color(0xB8FFFFFF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Complaints Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Resolution velocity, category distribution and queue health',
                          style: TextStyle(
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
                                icon: Icons.pending_actions_rounded,
                                label: '$active Active',
                              ),
                              const SizedBox(width: 8),
                              _headerPill(
                                icon: Icons.check_circle_rounded,
                                label: '$rate% Resolved Rate',
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
    });
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
  bool shouldRebuild(covariant _ComplaintsHomeHeaderDelegate oldDelegate) =>
      true;
}

/// Themed status stat card for the 2x2 Queue Breakdown grid.
class _StatusStatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusStatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder during initial load of Complaints Overview.
class _ComplainHomeShimmer extends StatelessWidget {
  final double topPadding;

  const _ComplainHomeShimmer({required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: topPadding + 195.0,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SkeletonLoader(
                      height: 10,
                      width: 110,
                      borderRadius: BorderRadius.circular(4),
                      baseColor: Colors.white.withValues(alpha: 0.14),
                      highlightColor: Colors.white.withValues(alpha: 0.28),
                    ),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      height: 28,
                      width: 220,
                      borderRadius: BorderRadius.circular(6),
                      baseColor: Colors.white.withValues(alpha: 0.18),
                      highlightColor: Colors.white.withValues(alpha: 0.32),
                    ),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      height: 14,
                      width: 280,
                      borderRadius: BorderRadius.circular(4),
                      baseColor: Colors.white.withValues(alpha: 0.10),
                      highlightColor: Colors.white.withValues(alpha: 0.22),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (int i = 0; i < 2; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          SkeletonLoader(
                            height: 28,
                            width: 100,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusPill),
                            baseColor: Colors.white.withValues(alpha: 0.14),
                            highlightColor: Colors.white.withValues(alpha: 0.28),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.gapLg,
              AppDimens.screenPadding,
              100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Volume Shimmer
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(height: 14, width: 90),
                            const SizedBox(height: 8),
                            SkeletonLoader(height: 32, width: 60),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 48,
                        color: AppColors.border,
                      ),
                      const SizedBox(width: AppDimens.gapLg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(height: 14, width: 90),
                            const SizedBox(height: 8),
                            SkeletonLoader(height: 32, width: 70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.gapXl),
                // Queue Breakdown Shimmer
                const SkeletonLoader(height: 18, width: 140),
                const SizedBox(height: AppDimens.gapSm),
                Row(
                  children: const [
                    Expanded(child: SkeletonLoader(height: 90, borderRadius: BorderRadius.all(Radius.circular(16)))),
                    SizedBox(width: AppDimens.gapMd),
                    Expanded(child: SkeletonLoader(height: 90, borderRadius: BorderRadius.all(Radius.circular(16)))),
                  ],
                ),
                const SizedBox(height: AppDimens.gapMd),
                Row(
                  children: const [
                    Expanded(child: SkeletonLoader(height: 90, borderRadius: BorderRadius.all(Radius.circular(16)))),
                    SizedBox(width: AppDimens.gapMd),
                    Expanded(child: SkeletonLoader(height: 90, borderRadius: BorderRadius.all(Radius.circular(16)))),
                  ],
                ),
                const SizedBox(height: AppDimens.gapXl),
                // Chart Shimmers
                const SkeletonLoader(height: 180, borderRadius: BorderRadius.all(Radius.circular(16))),
                const SizedBox(height: AppDimens.gapLg),
                const SkeletonLoader(height: 180, borderRadius: BorderRadius.all(Radius.circular(16))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
