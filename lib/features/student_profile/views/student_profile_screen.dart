import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/student_profile/student_profile_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../phonebook/services/phone_number_normalizer.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/student_contact_card.dart'
    show CelebrantLightChip, CornerWavePainter;
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
                  parent: ClampingScrollPhysics(),
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
                          const _CampusHubSection(),
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Personal details'),
                          _DetailsCard(
                            rows: [
                              if (profile.whatsappNumber.isNotEmpty &&
                                  profile.phone.isNotEmpty &&
                                  PhoneNumberNormalizer.isSame(
                                      profile.phone, profile.whatsappNumber))
                                InfoRow(
                                  icon: Icons.phone_android_rounded,
                                  label: 'Phone & WhatsApp',
                                  value: profile.phone,
                                )
                              else ...[
                                if (profile.phone.isNotEmpty)
                                  InfoRow(
                                    icon: Icons.phone_outlined,
                                    label: 'Phone',
                                    value: profile.phone,
                                  ),
                                if (profile.whatsappNumber.isNotEmpty)
                                  InfoRow(
                                    icon: Icons.chat_outlined,
                                    label: 'WhatsApp',
                                    value: profile.whatsappNumber,
                                  ),
                              ],
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

    final hasPills =
        profile.room.isNotEmpty ||
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
      actions: [
        Obx(() {
          final controller = Get.find<StudentProfileController>();
          final unread = controller.unreadAnnouncementsCount.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              HeaderIconButton(
                icon: Icons.campaign_rounded,
                tooltip: 'Announcements',
                onPressed: () => Get.toNamed(
                  Routes.broadcastInbox,
                )?.then((_) => controller.loadHubBadges()),
              ),
              if (unread > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        HeaderIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: () => Get.toNamed(Routes.setting),
        ),
      ],
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

    final hasCachedPills =
        cached != null &&
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
                                borderRadius: BorderRadius.all(
                                  Radius.circular(6),
                                ),
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

class _CampusHubSection extends StatelessWidget {
  const _CampusHubSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StudentProfileController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'CAMPUS UPDATES & FEEDBACK',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Announcements Card
            Expanded(
              child: _HubActionCard(
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFFDB2777),
                iconBg: const Color(0xFFFDF2F8),
                iconBorder: const Color(0xFFFBCFE8),
                waveColor: const Color(0xFFFCE7F3),
                title: 'Announcements',
                subtitle: 'Office notices & news',
                badgeBuilder: () => Obx(() {
                  final unread = controller.unreadAnnouncementsCount.value;
                  return CelebrantLightChip(
                    icon: unread > 0
                        ? Icons.mark_email_unread_rounded
                        : Icons.done_all_rounded,
                    text: unread > 0 ? '$unread New' : 'Up to date',
                    bgColor: unread > 0
                        ? const Color(0xFFFDF2F8)
                        : const Color(0xFFF8FAFC),
                    borderColor: unread > 0
                        ? const Color(0xFFFBCFE8)
                        : const Color(0xFFE2E8F0),
                    textColor: unread > 0
                        ? const Color(0xFFDB2777)
                        : const Color(0xFF64748B),
                  );
                }),
                onTap: () => Get.toNamed(
                  Routes.broadcastInbox,
                )?.then((_) => controller.loadHubBadges()),
              ),
            ),
            const SizedBox(width: 12),
            // Polls & Forms Card
            Expanded(
              child: _HubActionCard(
                icon: Icons.how_to_vote_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF5F3FF),
                iconBorder: const Color(0xFFDDD6FE),
                waveColor: const Color(0xFFEDE9FE),
                title: 'Polls & Forms',
                subtitle: 'Hostel decisions & votes',
                badgeBuilder: () => Obx(() {
                  final pending = controller.pendingFormsCount.value;
                  return CelebrantLightChip(
                    icon: pending > 0
                        ? Icons.pending_actions_rounded
                        : Icons.check_circle_outline_rounded,
                    text: pending > 0 ? '$pending to answer' : 'Completed',
                    bgColor: pending > 0
                        ? const Color(0xFFF5F3FF)
                        : const Color(0xFFECFDF5),
                    borderColor: pending > 0
                        ? const Color(0xFFDDD6FE)
                        : const Color(0xFFA7F3D0),
                    textColor: pending > 0
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF059669),
                  );
                }),
                onTap: () => Get.toNamed(
                  Routes.studentForms,
                )?.then((_) => controller.loadHubBadges()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HubActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color iconBorder;
  final Color waveColor;
  final String title;
  final String subtitle;
  final Widget Function() badgeBuilder;
  final VoidCallback onTap;

  const _HubActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.iconBorder,
    required this.waveColor,
    required this.title,
    required this.subtitle,
    required this.badgeBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(80, 55),
                  painter: CornerWavePainter(
                    color: waveColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: iconBorder, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: Icon(icon, color: iconColor, size: 21),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    badgeBuilder(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
