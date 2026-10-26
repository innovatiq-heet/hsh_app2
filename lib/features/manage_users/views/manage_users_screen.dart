import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/responses/staff_users/staff_user.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/manage_users_controller.dart';
import '../widgets/staff_user_form_sheet.dart';

/// Admin → Manage Users: list, add, edit, switch on/off and delete staff
/// accounts that sign in with their mobile number.
class ManageUsersScreen extends GetView<ManageUsersController> {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Obx(
        () => Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: AsyncStateView(
            isLoading: controller.isLoading.value,
            hasError: controller.hasError.value,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.load,
            loadingWidget: _ManageUsersShimmer(topPadding: topPadding),
            builder: (context) => Obx(() {
              final users = controller.users;
              final active = users.where((u) => u.isActive).length;
              return AppRefreshIndicator(
                onRefresh: () => controller.load(showLoading: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ManageUsersHeaderDelegate(
                        topPadding: topPadding,
                        userCount: users.length,
                        activeCount: active,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapXl,
                        AppDimens.screenPadding,
                        100,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: users.isEmpty
                            ? EmptyState(
                                icon: Icons.manage_accounts_outlined,
                                title: 'No users yet',
                                message:
                                    'Add complaint solvers and laundry staff. They sign in with their mobile number.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SectionHeader(title: 'Staff users'),
                                  for (int i = 0; i < users.length; i++)
                                    StaggeredSlideFade(
                                      index: i,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppDimens.gapMd,
                                        ),
                                        child: _StaffUserCard(user: users[i]),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          floatingActionButton:
              controller.isLoading.value || controller.hasError.value
                  ? null
                  : FloatingActionButton.extended(
                      heroTag: null,
                      backgroundColor: const Color(0xFF0369A1),
                      foregroundColor: Colors.white,
                      onPressed: () => StaffUserFormSheet.show(),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text(
                        'Add user',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
        ),
      ),
    );
  }
}

/// Collapsible deep-navy header matching the Screen Time / Geofence /
/// Complaints Desk screens.
class _ManageUsersHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final int userCount;
  final int activeCount;

  const _ManageUsersHeaderDelegate({
    required this.topPadding,
    required this.userCount,
    required this.activeCount,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent => topPadding + 185.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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

            // Top pinned nav bar
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
                      child: const Text(
                        'Manage Users',
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
                        'ADMIN',
                        style: TextStyle(
                          color: Color(0xB8FFFFFF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Manage Users',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Staff who sign in with their mobile number',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _headerPill(
                            icon: Icons.people_alt_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            label: '$userCount users',
                          ),
                          const SizedBox(width: 8),
                          _headerPill(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF34D399),
                            label: '$activeCount active',
                          ),
                        ],
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

  Widget _headerPill({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
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
          Icon(icon, size: 12, color: iconColor ?? Colors.white),
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
  bool shouldRebuild(covariant _ManageUsersHeaderDelegate oldDelegate) => true;
}

class _StaffUserCard extends GetView<ManageUsersController> {
  final StaffUser user;

  const _StaffUserCard({required this.user});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete user?'),
        content: Text(
          '${user.name} (${user.phoneNumber}) will be removed and can no longer sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.delete(user);
  }

  @override
  Widget build(BuildContext context) {
    final roleStyle = _RoleStyle.of(user.role);
    return Opacity(
      opacity: user.isActive ? 1 : 0.6,
      child: AppCard(
        onTap: () => StaffUserFormSheet.show(user: user),
        child: Row(
          children: [
            // Role avatar circle with themed color
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: roleStyle.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: roleStyle.color.withValues(alpha: 0.30),
                  width: 1.5,
                ),
              ),
              child: Icon(roleStyle.icon, size: 22, color: roleStyle.color),
            ),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.phoneNumber,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: AppDimens.gapXs,
                    runSpacing: AppDimens.gapXs,
                    children: [
                      StatusBadge(label: user.roleLabel, color: roleStyle.color),
                      if (!user.isActive)
                        const StatusBadge(
                          label: 'Inactive',
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                  if (user.isComplaintSolver) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.categoriesLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Obx(() {
              final busy = controller.busyIds.contains(user.id);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: user.isActive,
                    activeTrackColor: const Color(0xFF0369A1),
                    onChanged:
                        busy ? null : (v) => controller.setActive(user, v),
                  ),
                  PopupMenuButton<String>(
                    enabled: !busy,
                    tooltip: 'More',
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (action) {
                      if (action == 'edit') StaffUserFormSheet.show(user: user);
                      if (action == 'delete') _confirmDelete(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: AppDimens.gapSm),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.errorRed,
                            ),
                            SizedBox(width: AppDimens.gapSm),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Icon and accent color per staff role.
class _RoleStyle {
  final IconData icon;
  final Color color;

  const _RoleStyle(this.icon, this.color);

  static _RoleStyle of(String role) {
    switch (UserRoleX.fromApi(role)) {
      case UserRole.complainsolver:
        return const _RoleStyle(Icons.handyman_rounded, Color(0xFF7C3AED));
      case UserRole.laundry:
        return const _RoleStyle(
          Icons.local_laundry_service_rounded,
          Color(0xFF0284C7),
        );
      default:
        return const _RoleStyle(Icons.badge_outlined, AppColors.primary);
    }
  }
}

/// Skeleton loading state for Manage Users.
class _ManageUsersShimmer extends StatelessWidget {
  final double topPadding;
  const _ManageUsersShimmer({required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: topPadding + 185,
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
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(34)),
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
                        width: 60,
                        borderRadius: BorderRadius.circular(4),
                        baseColor: Colors.white.withValues(alpha: 0.14),
                        highlightColor: Colors.white.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        height: 28,
                        width: 180,
                        borderRadius: BorderRadius.circular(6),
                        baseColor: Colors.white.withValues(alpha: 0.18),
                        highlightColor: Colors.white.withValues(alpha: 0.32),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        height: 14,
                        width: 260,
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
                              width: 80,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusPill),
                              baseColor: Colors.white.withValues(alpha: 0.14),
                              highlightColor:
                                  Colors.white.withValues(alpha: 0.28),
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.gapXl,
              AppDimens.screenPadding,
              100,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonLoader(
                    height: 16,
                    width: 100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  for (int i = 0; i < 4; i++)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppDimens.gapMd),
                      child: AppCard(
                        child: Row(
                          children: [
                            SkeletonLoader(
                              height: 48,
                              width: 48,
                              borderRadius: BorderRadius.circular(24),
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
                                    width: 100,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  const SizedBox(height: 8),
                                  SkeletonLoader(
                                    height: 22,
                                    width: 80,
                                    borderRadius: BorderRadius.circular(
                                        AppDimens.radiusPill),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            SkeletonLoader(
                              height: 32,
                              width: 50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
  }
}
