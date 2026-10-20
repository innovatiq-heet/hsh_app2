import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/complaint_orders_controller.dart';
import '../widgets/complaint_card.dart';

/// Complaints Desk: the solver queue with status tabs, a category filter
/// and a room search, all applied by the API.
class ComplainOrdersScreen extends GetView<ComplainOrdersController> {
  const ComplainOrdersScreen({super.key});

  Future<void> _logout() async {
    await Get.find<SessionStore>().clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Solvers land here as their home screen; admins arrive from the
    // console and go back instead of logging out.
    final isRoot = !Navigator.canPop(context);
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          loadingWidget: const _ComplainOrdersShimmer(),
          builder: (context) => Obx(() {
            final list = controller.complaints;
            final status = controller.statusFilter.value;
            final more = controller.hasMore.value ? '+' : '';
            return AppRefreshIndicator(
              onRefresh: () => controller.load(showLoading: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverGradientHeader(
                    overline: 'Staff Operations',
                    title: 'Complaints Desk',
                    subtitle: 'Review room complaints and move them to done',
                    expandedHeight: 270.0,
                    leading: isRoot
                        ? null
                        : HeaderIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: () => Get.back(),
                          ),
                    actions: [
                      HeaderIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh',
                        onPressed: controller.load,
                      ),
                      if (isRoot)
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
                            icon: status?.icon ?? Icons.assignment_rounded,
                            label: '${list.length}$more ${status?.staffLabel ?? 'All'}',
                          ),
                          if (controller.roomFilter.value.isNotEmpty) ...[
                            const SizedBox(width: AppDimens.gapSm),
                            HeaderPill(
                              icon: Icons.meeting_room_outlined,
                              label: 'Room ${controller.roomFilter.value}',
                            ),
                          ],
                        ],
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
                          const _FiltersCard(),
                          const SizedBox(height: AppDimens.gapLg),
                          SectionHeader(
                            title: status == null
                                ? 'All complaints'
                                : '${status.staffLabel} complaints',
                          ),
                          const SizedBox(height: AppDimens.gapSm),
                          if (list.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: EmptyState(
                                icon: Icons.assignment_outlined,
                                title: 'No complaints found',
                                message: controller.hasFilters
                                    ? 'No complaints match these filters.'
                                    : 'There are no room complaints yet.',
                              ),
                            )
                          else ...[
                            for (final c in list)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimens.gapMd,
                                ),
                                child: ComplaintCard(
                                  complaint: c,
                                  showStudent: true,
                                  staffLabels: true,
                                  onTap: () => Get.toNamed(
                                    Routes.complainAdminDetail,
                                    arguments: c.id,
                                  )?.then(
                                    (_) => controller.load(showLoading: false),
                                  ),
                                  trailing: _StatusMenu(complaint: c),
                                ),
                              ),
                            if (controller.hasMore.value)
                              AppButton(
                                label: 'Load more',
                                icon: Icons.expand_more_rounded,
                                variant: AppButtonVariant.outline,
                                isLoading: controller.isLoadingMore.value,
                                onPressed: controller.loadMore,
                              ),
                          ],
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

/// Room search plus status and category chips.
class _FiltersCard extends GetView<ComplainOrdersController> {
  const _FiltersCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      child: Obx(() {
        final status = controller.statusFilter.value;
        final category = controller.categoryFilter.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: controller.roomController,
              label: 'Room',
              hint: 'Exact room number, e.g. 101',
              prefixIcon: Icons.meeting_room_outlined,
              onChanged: (value) => controller.roomQuery.value = value,
              suffix: controller.roomQuery.value.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Clear room',
                      onPressed: controller.clearRoom,
                    ),
            ),
            const SizedBox(height: AppDimens.gapMd),
            _label('Status'),
            const SizedBox(height: AppDimens.gapXs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ComplaintStatus.values) ...[
                    _FilterChip(
                      label: s.staffLabel,
                      isSelected: status == s,
                      statusColor: s.color,
                      onSelected: () => controller.setStatusFilter(s),
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                  ],
                  _FilterChip(
                    label: 'All',
                    isSelected: status == null,
                    onSelected: () => controller.setStatusFilter(null),
                  ),
                ],
              ),
            ),
            if (controller.categories.isNotEmpty) ...[
              const SizedBox(height: AppDimens.gapMd),
              _label('Category'),
              const SizedBox(height: AppDimens.gapXs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Categories',
                      isSelected: category == null,
                      activeColor: AppColors.secondary,
                      onSelected: () => controller.setCategoryFilter(null),
                    ),
                    for (final cat in controller.categories) ...[
                      const SizedBox(width: AppDimens.gapSm),
                      _FilterChip(
                        label: cat.name,
                        isSelected: category?.id == cat.id,
                        activeColor: AppColors.secondary,
                        onSelected: () => controller.setCategoryFilter(
                          category?.id == cat.id ? null : cat,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      );
}

/// Quick status change on a queue row; any status may move to any other.
class _StatusMenu extends GetView<ComplainOrdersController> {
  final ComplaintResponse complaint;

  const _StatusMenu({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.updatingId.value == complaint.id) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return PopupMenuButton<ComplaintStatus>(
        tooltip: 'Change status',
        icon: const Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onSelected: (s) => controller.changeStatus(complaint, s),
        itemBuilder: (_) => [
          for (final s in ComplaintStatus.values)
            PopupMenuItem(
              value: s,
              enabled: s != complaint.status,
              child: Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: AppDimens.gapSm),
                  Text(
                    s == complaint.status
                        ? '${s.staffLabel} (current)'
                        : 'Move to ${s.staffLabel}',
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? statusColor;
  final Color activeColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.statusColor,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isSelected ? activeColor : AppColors.surfaceMuted;
    final activeText = isSelected ? Colors.white : AppColors.textPrimary;

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
              color: isSelected ? activeColor : AppColors.border,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ComplainOrdersShimmer extends StatelessWidget {
  const _ComplainOrdersShimmer();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverGradientHeader(
          overline: 'Staff Operations',
          title: 'Complaints Desk',
          subtitle: 'Review room complaints and move them to done',
          expandedHeight: 270.0,
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
            if (!Navigator.canPop(context))
              HeaderIconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Log out',
                onPressed: () {},
              ),
          ],
          child: Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppDimens.gapSm),
                SkeletonLoader(
                  height: 34,
                  width: 104,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  baseColor: Colors.white.withValues(alpha: 0.14),
                  highlightColor: Colors.white.withValues(alpha: 0.32),
                ),
              ],
            ],
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
                AppCard(
                  padding: const EdgeInsets.all(AppDimens.gapMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SkeletonLoader(
                        height: 48,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      Row(
                        children: [
                          SkeletonLoader(
                            height: 12,
                            width: 80,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapSm),
                      Row(
                        children: [
                          for (int i = 0; i < 4; i++) ...[
                            if (i > 0) const SizedBox(width: AppDimens.gapSm),
                            SkeletonLoader(
                              height: 32,
                              width: 72,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusPill,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.gapLg),
                Row(
                  children: [
                    SkeletonLoader(
                      height: 16,
                      width: 160,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapSm),
                for (int i = 0; i < 3; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppDimens.gapMd),
                    child: _StaffComplaintCardShimmer(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffComplaintCardShimmer extends StatelessWidget {
  const _StaffComplaintCardShimmer();

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
                      width: 150,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    SkeletonLoader(
                      height: 12,
                      width: 100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.gapSm),
              SkeletonLoader(
                height: 24,
                width: 70,
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
            width: 220,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ],
      ),
    );
  }
}
