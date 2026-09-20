import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../../storage/session_store.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/brand.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/section_list_tile.dart';
import '../student_profile/student_profile_controller.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  Future<void> _logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBadge(
              icon: Icons.logout_rounded,
              color: AppColors.cancelledRed,
              size: 56,
            ),
            const SizedBox(height: AppDimens.gapLg),
            Text('Log out?', style: AppTextStyles.headline),
            const SizedBox(height: AppDimens.gapSm),
            Text(
              'Are you sure you want to log out of ${AppStrings.appName}? You will need to sign in again to access your account.',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.gapXl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: AppButton(
                    label: AppStrings.logout,
                    variant: AppButtonVariant.danger,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _logout();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.screenPadding,
            vertical: AppDimens.gapLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.gapLg),
              Text('Select Language', style: AppTextStyles.headline),
              const SizedBox(height: AppDimens.gapSm),
              Text(
                'Choose your preferred application language',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: AppDimens.gapLg),
              _LanguageTile(
                title: 'English',
                subtitle: 'English (Default)',
                isSelected: true,
                onTap: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: AppDimens.gapSm),
              _LanguageTile(
                title: 'हिन्दी',
                subtitle: 'Hindi',
                isSelected: false,
                onTap: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: AppDimens.gapSm),
              _LanguageTile(
                title: 'ગુજરાતી',
                subtitle: 'Gujarati',
                isSelected: false,
                onTap: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: AppDimens.gapXl),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.screenPadding,
            vertical: AppDimens.gapLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimens.gapXl),
              const BrandLogo(size: 64),
              const SizedBox(height: AppDimens.gapLg),
              Text(AppStrings.appName, style: AppTextStyles.headline),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0 (Build 100)',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppDimens.gapLg),
              Text(
                'Hari Saurabh Hostel resident companion app provides seamless access to attendance tracking, laundry tickets, room complaints, and leave applications.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.gapXxl),
              AppButton(
                label: 'Close',
                variant: AppButtonVariant.primary,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    StudentProfileController? profileController;
    if (Get.isRegistered<StudentProfileController>()) {
      profileController = Get.find<StudentProfileController>();
    }

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: CustomScrollView(
        slivers: [
          // Hero Gradient Header matching the app theme
          SliverGradientHeader(
            overline: 'Account & Preferences',
            title: 'Settings',
            subtitle: 'Manage your profile and app preferences',
            expandedHeight: 220.0,
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
            child: const HeaderPill(
              icon: Icons.apartment_rounded,
              label: 'Hari Saurabh Hostel',
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapLg,
              AppDimens.screenPadding,
              AppDimens.gapXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Resident Profile Summary Card (if available)
                if (profileController != null)
                  Obx(() {
                    final profile = profileController!.profile.value;
                    if (profile == null) return const SizedBox.shrink();
                    final initial = profile.firstName.isNotEmpty
                        ? profile.firstName[0].toUpperCase()
                        : 'S';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.gapXl),
                      child: AppCard(
                        onTap: () => Get.toNamed(
                          Routes.studentProfileEdit,
                          arguments: profile,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: AppTextStyles.title.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName.isNotEmpty
                                        ? profile.fullName
                                        : 'Resident Account',
                                    style: AppTextStyles.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusPill,
                                          ),
                                        ),
                                        child: Text(
                                          'Room ${profile.room}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppDimens.gapSm),
                                      Expanded(
                                        child: Text(
                                          profile.phone.isNotEmpty
                                              ? profile.phone
                                              : profile.email,
                                          style: AppTextStyles.bodySm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SectionHeader(title: 'Account'),
                _Group(
                  children: [
                    SectionListTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit profile',
                      subtitle: 'Contact, address, family, vehicle',
                      iconColor: AppColors.primary,
                      onTap: () => Get.toNamed(
                        Routes.studentProfileEdit,
                        arguments: profileController?.profile.value,
                      ),
                    ),
                    SectionListTile(
                      icon: Icons.grid_view_rounded,
                      title: 'All services',
                      subtitle: 'Laundry, complaints, attendance & leave',
                      iconColor: AppColors.secondary,
                      onTap: () => Get.toNamed(Routes.services),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapXl),

                const SectionHeader(title: 'Preferences'),
                _Group(
                  children: [
                    SectionListTile(
                      icon: Icons.translate_rounded,
                      title: 'Language',
                      subtitle: 'English',
                      iconColor: AppColors.secondaryLight,
                      onTap: () => _showLanguageSheet(context),
                    ),
                    SectionListTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: AppStrings.appName,
                      iconColor: AppColors.primaryLight,
                      onTap: () => _showAboutSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapXl),

                const SectionHeader(title: 'Session'),
                _Group(
                  children: [
                    SectionListTile(
                      icon: Icons.logout_rounded,
                      title: AppStrings.logout,
                      subtitle: 'Sign out from this device',
                      iconColor: AppColors.cancelledRed,
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.cancelledRed,
                      ),
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapXxl),

                // Branded Footer
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.apartment_rounded,
                        size: 28,
                        color: AppColors.textMuted.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: AppDimens.gapXs),
                      Text(
                        AppStrings.appName,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version 1.0.0 • Designed for Residents',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
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
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySm),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.gapSm,
        vertical: AppDimens.gapXs,
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 68, endIndent: AppDimens.gapSm),
            children[i],
          ],
        ],
      ),
    );
  }
}

