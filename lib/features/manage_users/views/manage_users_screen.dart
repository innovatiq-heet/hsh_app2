import 'package:flutter/material.dart';
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
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
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
    return Obx(
      () => Scaffold(
        // The back button lives in the sliver header, which an error hides.
        appBar: controller.hasError.value
            ? AppBar(title: const Text('Manage Users'))
            : null,
        body: AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          loadingWidget: const SafeArea(child: SkeletonList()),
          builder: (context) => Obx(() {
            final users = controller.users;
            final active = users.where((u) => u.isActive).length;
            return AppRefreshIndicator(
              onRefresh: () => controller.load(showLoading: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverGradientHeader(
                    overline: 'Admin',
                    title: 'Manage Users',
                    subtitle: 'Staff who sign in with their mobile number',
                    expandedHeight: 220.0,
                    leading: HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Get.back(),
                    ),
                    child: Row(
                      children: [
                        HeaderPill(
                          icon: Icons.people_alt_rounded,
                          label: '${users.length} users',
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        HeaderPill(
                          icon: Icons.check_circle_rounded,
                          label: '$active active',
                        ),
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
                    onPressed: () => StaffUserFormSheet.show(),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add user'),
                  ),
      ),
    );
  }
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
            IconBadge(icon: roleStyle.icon, color: roleStyle.color, size: 44),
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
                  Text(
                    user.phoneNumber,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
                    onChanged: busy ? null : (v) => controller.setActive(user, v),
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
