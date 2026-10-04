import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/student_profile/student_profile_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/student_profile_controller.dart';

class StudentProfileScreen extends GetView<StudentProfileController> {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.refreshProfile,
          loadingWidget: const _ProfileSkeleton(),
          builder: (context) {
            final profile = controller.profile.value;
            if (profile == null) return const SizedBox.shrink();
            return AppRefreshIndicator(
              onRefresh: controller.refreshProfile,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics()
                ),
                slivers: [
                  _ProfileHero(profile: profile),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapXl,
                        AppDimens.screenPadding,
                        AppDimens.gapXl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // const SectionHeader(title: 'Quick actions'),
                          // const _QuickActions(),
                          // const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Personal details'),
                          _DetailsCard(
                            rows: [
                              InfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: profile.phone,
                              ),
                              InfoRow(
                                icon: Icons.chat_outlined,
                                label: 'WhatsApp',
                                value: profile.whatsappNumber,
                              ),
                              InfoRow(
                                icon: Icons.alternate_email_rounded,
                                label: 'Email',
                                value: profile.email,
                                locked: true,
                              ),
                              if (profile.dob.isNotEmpty)
                                InfoRow(
                                  icon: Icons.cake_outlined,
                                  label: 'Date of birth',
                                  value: profile.dob,
                                  locked: true,
                                ),
                              InfoRow(
                                icon: Icons.bloodtype_outlined,
                                label: 'Blood group',
                                value: profile.bloodGroup,
                              ),
                              InfoRow(
                                icon: Icons.two_wheeler_outlined,
                                label: 'Vehicle',
                                value: profile.vehicleNumber,
                              ),
                            ],
                          ),
                          // if (profile.fatherPhone.isNotEmpty ||
                          //     profile.motherPhone.isNotEmpty) ...[
                          //   const SizedBox(height: AppDimens.gapXl),
                          //   const SectionHeader(
                          //     title: 'Parent & guardian contact',
                          //   ),
                          //   _DetailsCard(
                          //     rows: [
                          //       if (profile.fatherPhone.isNotEmpty)
                          //         InfoRow(
                          //           icon: Icons.family_restroom_outlined,
                          //           label: "Father's phone",
                          //           value: profile.fatherPhone,
                          //         ),
                          //       if (profile.motherPhone.isNotEmpty)
                          //         InfoRow(
                          //           icon: Icons.family_restroom_outlined,
                          //           label: "Mother's phone",
                          //           value: profile.motherPhone,
                          //         ),
                          //     ],
                          //   ),
                          // ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final StudentProfileModel profile;

  const _ProfileHero({required this.profile});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final initial = profile.firstName.isNotEmpty
        ? profile.firstName[0].toUpperCase()
        : '?';

    final fullName = profile.fullName.trim();
    final double titleFontSize = fullName.length > 25
        ? 16.0
        : (fullName.length > 18 ? 18.0 : 20.0);

    final hasPills = profile.room.isNotEmpty ||
        profile.groupName.isNotEmpty ||
        profile.bankCode.isNotEmpty;

    return SliverGradientHeader(
      expandedHeight: hasPills ? 145 : 96,
      overline: _greeting,
      title: fullName.isNotEmpty ? fullName : 'Student Profile',
      titleStyle: AppTextStyles.headline.copyWith(
        fontSize: titleFontSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.25,
      ),
      titleMaxLines: 2,
      heroLeading: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: Text(
            initial,
            style: AppTextStyles.headline.copyWith(color: AppColors.primary),
          ),
        ),
      ),
      // actions: [
      //   HeaderIconButton(
      //     icon: Icons.settings_outlined,
      //     tooltip: 'Settings',
      //     onPressed: () => Get.toNamed(Routes.setting),
      //   ),
      // ],
      child: Builder(
        builder: (context) {
          final pills = [
            if (profile.room.isNotEmpty)
              HeaderPill(
                icon: Icons.meeting_room_outlined,
                label: profile.room.toLowerCase().contains('room')
                    ? profile.room
                    : 'Room ${profile.room}',
              ),
            if (profile.groupName.isNotEmpty)
              HeaderPill(icon: Icons.groups_outlined, label: profile.groupName),
            if (profile.bankCode.isNotEmpty)
              HeaderPill(
                icon: Icons.badge_outlined,
                label: 'ID: ${profile.bankCode}',
              ),
          ];
          if (pills.isEmpty) return const SizedBox.shrink();
          return Row(
            children: [
              for (int i = 0; i < pills.length; i++) ...[
                if (i > 0) const SizedBox(width: AppDimens.gapSm),
                Expanded(child: pills[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _QuickAction(this.label, this.icon, this.color, this.route);
}

// ignore: unused_element
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    _QuickAction(
      'Leave',
      Icons.beach_access_outlined,
      AppColors.secondary,
      Routes.leave,
    ),
    _QuickAction(
      'Payments',
      Icons.account_balance_wallet_outlined,
      AppColors.successGreen,
      Routes.fees,
    ),
    _QuickAction(
      'Notes',
      Icons.sticky_note_2_outlined,
      AppColors.warningOrange,
      Routes.notes,
    ),
    _QuickAction(
      'More',
      Icons.grid_view_rounded,
      AppColors.primary,
      Routes.services,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.gapLg),
              onTap: () => Get.toNamed(_actions[i].route),
              child: Column(
                children: [
                  IconBadge(
                    icon: _actions[i].icon,
                    color: _actions[i].color,
                    size: 42,
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  Text(
                    _actions[i].label,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<Widget> rows;

  const _DetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.cardPadding,
        vertical: AppDimens.gapSm,
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final cached = Get.isRegistered<StudentProfileController>()
        ? Get.find<StudentProfileController>().profile.value
        : null;

    final initial = (cached != null && cached.firstName.isNotEmpty)
        ? cached.firstName[0].toUpperCase()
        : '';

        final skeletonTitle = (cached?.fullName ?? 'Student Profile').trim();
        final double skeletonTitleSize = skeletonTitle.length > 25
            ? 16.0
            : (skeletonTitle.length > 18 ? 18.0 : 20.0);

        final hasCachedPills = cached != null &&
            (cached.room.isNotEmpty ||
                cached.groupName.isNotEmpty ||
                cached.bankCode.isNotEmpty);

        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverGradientHeader(
              expandedHeight: hasCachedPills ? 145 : 96,
              overline: _greeting,
              title: skeletonTitle,
              titleStyle: AppTextStyles.headline.copyWith(
                fontSize: skeletonTitleSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.25,
              ),
              titleMaxLines: 2,
          heroLeading: Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: initial.isNotEmpty
                  ? Text(
                      initial,
                      style: AppTextStyles.headline.copyWith(
                        color: AppColors.primary,
                      ),
                    )
                  : SkeletonLoader(
                      width: 58,
                      height: 58,
                      borderRadius: BorderRadius.circular(999),
                      baseColor: AppColors.primary.withValues(alpha: 0.15),
                      highlightColor: AppColors.primary.withValues(alpha: 0.35),
                    ),
            ),
          ),
          actions: [
            HeaderIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onPressed: () {},
            ),
          ],
          child: Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppDimens.gapSm),
                Expanded(
                  child: SkeletonLoader(
                    height: 32,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    baseColor: Colors.white.withValues(alpha: 0.18),
                    highlightColor: Colors.white.withValues(alpha: 0.40),
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
              AppDimens.gapXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Quick actions'),
                Row(
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimens.gapLg,
                          ),
                          child: Column(
                            children: const [
                              SkeletonLoader(
                                width: 42,
                                height: 42,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(AppDimens.radiusMd),
                                ),
                              ),
                              SizedBox(height: AppDimens.gapSm),
                              SkeletonLoader(width: 44, height: 11),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppDimens.gapXl),
                const SectionHeader(title: 'Personal details'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.cardPadding,
                    vertical: AppDimens.gapSm,
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < 6; i++) ...[
                        if (i > 0) const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: const [
                              SkeletonLoader(
                                width: 20,
                                height: 20,
                                borderRadius: BorderRadius.all(Radius.circular(6)),
                              ),
                              SizedBox(width: AppDimens.gapMd),
                              SkeletonLoader(width: 70, height: 14),
                              Spacer(),
                              SkeletonLoader(width: 120, height: 14),
                            ],
                          ),
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
    );
  }
}
