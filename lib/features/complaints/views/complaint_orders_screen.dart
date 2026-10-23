import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final isRoot = !Navigator.canPop(context);
    final topPadding = MediaQuery.of(context).padding.top;
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
            loadingWidget: _ComplainOrdersShimmer(isRoot: isRoot),
            builder: (context) => Obx(() {
              final list = controller.complaints;
              final status = controller.statusFilter.value;
              return AppRefreshIndicator(
                onRefresh: () => controller.load(showLoading: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ComplaintsHeaderDelegate(
                        controller: controller,
                        topPadding: topPadding,
                        isRoot: isRoot,
                        onLogout: _logout,
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
                  _FilterChip(
                    label: 'All',
                    icon: Icons.list_rounded,
                    isSelected: status == null,
                    onSelected: () => controller.setStatusFilter(null),
                  ),
                  for (final s in ComplaintStatus.values) ...[
                    const SizedBox(width: AppDimens.gapSm),
                    _FilterChip(
                      label: s.staffLabel,
                      icon: s.icon,
                      isSelected: status == s,
                      statusColor: s.color,
                      onSelected: () => controller.setStatusFilter(s),
                    ),
                  ],
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
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? statusColor;
  final Color? activeColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.statusColor,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActive = isSelected
        ? (activeColor ?? (statusColor != null ? statusColor! : AppColors.primary))
        : null;
    final bgColor = effectiveActive != null
        ? effectiveActive.withValues(alpha: 0.12)
        : AppColors.surfaceMuted;
    final borderColor = effectiveActive != null
        ? effectiveActive.withValues(alpha: 0.55)
        : AppColors.border;
    final iconColor =
        effectiveActive ?? AppColors.textSecondary;
    final textColor =
        effectiveActive ?? AppColors.textPrimary;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible deep-navy header matching the Screen Time / Geofence screens.
class _ComplaintsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ComplainOrdersController controller;
  final double topPadding;
  final bool isRoot;
  final Future<void> Function() onLogout;

  const _ComplaintsHeaderDelegate({
    required this.controller,
    required this.topPadding,
    required this.isRoot,
    required this.onLogout,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent => topPadding + 190.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular((34.0 * (1.0 - progress)).clamp(0.0, 34.0));

    return Obx(() {
      final totalCount = controller.complaints.length;
      final status = controller.statusFilter.value;
      final roomFilter = controller.roomFilter.value;

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
                    color: const Color(0xFF03192E).withValues(alpha: 0.22 * progress),
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
              // Decorative ambient orbs
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

              // Top nav row
              Positioned(
                top: topPadding + 6,
                left: 16,
                right: 16,
                height: 46,
                child: Row(
                  children: [
                    // Back / placeholder button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Get.back(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            isRoot ? Icons.menu_rounded : Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Collapsed title
                    Expanded(
                      child: Opacity(
                        opacity: collapsedTitleOpacity,
                        child: const Text(
                          'Complaints Desk',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Refresh
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: controller.load,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // Logout (only when solver uses as root screen)
                    if (isRoot) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onLogout,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Expanded content
              if (expandedOpacity > 0.05)
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
                          'STAFF OPERATIONS',
                          style: TextStyle(
                            color: Color(0xB8FFFFFF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Complaints Desk',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Review room complaints and move them to done',
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
                                icon: status?.icon ?? Icons.assignment_rounded,
                                label: '$totalCount${controller.hasMore.value ? '+' : ''} '
                                    '${status?.staffLabel ?? 'All'}',
                              ),
                              if (roomFilter.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _headerPill(
                                  icon: Icons.meeting_room_outlined,
                                  label: 'Room $roomFilter',
                                ),
                              ],
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
  bool shouldRebuild(covariant _ComplaintsHeaderDelegate oldDelegate) => true;
}

class _ComplainOrdersShimmer extends StatelessWidget {
  final bool isRoot;
  const _ComplainOrdersShimmer({this.isRoot = false});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          // Shimmer header matching the real header style
          SliverToBoxAdapter(
            child: Container(
              height: topPadding + 190,
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
                        height: 10, width: 100,
                        borderRadius: BorderRadius.circular(4),
                        baseColor: Colors.white.withValues(alpha: 0.14),
                        highlightColor: Colors.white.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        height: 28, width: 220,
                        borderRadius: BorderRadius.circular(6),
                        baseColor: Colors.white.withValues(alpha: 0.18),
                        highlightColor: Colors.white.withValues(alpha: 0.32),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        height: 14, width: 280,
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
                              height: 28, width: 90,
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
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
      ),
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
