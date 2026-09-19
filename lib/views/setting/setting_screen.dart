import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_text_styles.dart';
import '../../storage/session_store.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/section_list_tile.dart';
import '../student_profile/student_profile_controller.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  Future<void> _logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapSm,
          AppDimens.screenPadding,
          AppDimens.gapXxl,
        ),
        children: [
          const SectionHeader(title: 'Account'),
          _Group(
            children: [
              SectionListTile(
                icon: Icons.edit_outlined,
                title: 'Edit profile',
                subtitle: 'Contact, address, family, vehicle',
                onTap: () => Get.toNamed(
                  Routes.studentProfileEdit,
                  arguments: Get.find<StudentProfileController>().profile.value,
                ),
              ),
              SectionListTile(
                icon: Icons.grid_view_rounded,
                title: 'All services',
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
                iconColor: AppColors.warningOrange,
                onTap: () {},
              ),
              SectionListTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: AppStrings.appName,
                iconColor: AppColors.successGreen,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapXl),
          _Group(
            children: [
              SectionListTile(
                icon: Icons.logout_rounded,
                title: AppStrings.logout,
                iconColor: AppColors.cancelledRed,
                trailing: const SizedBox.shrink(),
                onTap: _logout,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapXl),
          Center(child: Text('Version 1.0.0', style: AppTextStyles.caption)),
        ],
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
