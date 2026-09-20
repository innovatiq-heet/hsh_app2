import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/laundry_status.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../storage/session_store.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/chart_card.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'laundry_home_controller.dart';

class LaundryHomeScreen extends GetView<LaundryHomeController> {
  const LaundryHomeScreen({super.key});

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
        builder: (context) => RefreshIndicator(
          onRefresh: controller.load,
          child: CustomScrollView(
            slivers: [
              // Gradient Header
              SliverGradientHeader(
                overline: 'Performance & Analytics',
                title: 'Laundry Overview',
                subtitle:
                    'Ticket metrics, order distribution and processing queue',
                expandedHeight: 220.0,
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
                child: Row(
                  children: [
                    HeaderPill(
                      icon: Icons.receipt_long_rounded,
                      label: '${controller.totalTickets.value} Total Orders',
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    HeaderPill(
                      icon: Icons.checkroom_rounded,
                      label:
                          '${controller.totalGarments.value} Garments Processed',
                    ),
                  ],
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Orders',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${controller.totalTickets.value}',
                                    style: AppTextStyles.displayLg.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 46,
                              color: AppColors.border,
                            ),
                            const SizedBox(width: AppDimens.gapLg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Garments',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${controller.totalGarments.value}',
                                    style: AppTextStyles.displayLg.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapLg),

                      // 4 Status Cards Grid
                      const SectionHeader(title: 'Queue Breakdown'),
                      const SizedBox(height: AppDimens.gapSm),

                      Row(
                        children: [
                          Expanded(
                            child: _StatusStatCard(
                              title: 'Pending Intake',
                              count: controller.pendingCount.value,
                              color: LaundryStatus.pending.color,
                              icon: Icons.hourglass_top_rounded,
                            ),
                          ),
                          const SizedBox(width: AppDimens.gapMd),
                          Expanded(
                            child: _StatusStatCard(
                              title: 'Accepted',
                              count: controller.acceptedCount.value,
                              color: LaundryStatus.accepted.color,
                              icon: Icons.assignment_turned_in_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      Row(
                        children: [
                          Expanded(
                            child: _StatusStatCard(
                              title: 'In Washing',
                              count: controller.washedCount.value,
                              color: LaundryStatus.washed.color,
                              icon: Icons.local_laundry_service_outlined,
                            ),
                          ),
                          const SizedBox(width: AppDimens.gapMd),
                          Expanded(
                            child: _StatusStatCard(
                              title: 'Delivered',
                              count: controller.receivedCount.value,
                              color: LaundryStatus.received.color,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapXl),

                      // Distribution Chart
                      const SectionHeader(title: 'Status Distribution'),
                      const SizedBox(height: AppDimens.gapSm),
                      ChartCard(
                        title: 'Tickets by Status',
                        points: controller.statusCounts,
                      ),
                    ],
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
      padding: const EdgeInsets.all(AppDimens.gapLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(
            '$count',
            style: AppTextStyles.title.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
