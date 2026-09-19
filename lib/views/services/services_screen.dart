import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../home/home_controller.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/section_header.dart';
import '../student_profile/student_profile_controller.dart';

class _ServiceItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ServiceItem(this.label, this.icon, this.color, this.onTap);
}

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  void _goToTab(int index) {
    Get.find<HomeController>().changeTab(index);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<_ServiceItem>>{
      'Daily': [
        _ServiceItem(
          'Attendance',
          Icons.fact_check_outlined,
          AppColors.primary,
          () => _goToTab(3),
        ),
        _ServiceItem(
          'Laundry',
          Icons.local_laundry_service_outlined,
          AppColors.secondary,
          () => _goToTab(2),
        ),
        _ServiceItem(
          'Complaints',
          Icons.support_agent_outlined,
          AppColors.warningOrange,
          () => _goToTab(1),
        ),
      ],
      'Requests & money': [
        _ServiceItem(
          'Leave',
          Icons.beach_access_outlined,
          AppColors.secondary,
          () => Get.toNamed(Routes.leave),
        ),
        _ServiceItem(
          'Payments',
          Icons.account_balance_wallet_outlined,
          AppColors.successGreen,
          () => Get.toNamed(Routes.fees),
        ),
        _ServiceItem(
          'Vehicle',
          Icons.two_wheeler_outlined,
          const Color(0xFF8B5CF6),
          () => Get.toNamed(
            Routes.studentProfileEdit,
            arguments: Get.find<StudentProfileController>().profile.value,
          ),
        ),
      ],
      'Personal': [
        _ServiceItem(
          'Profile',
          Icons.person_outline_rounded,
          AppColors.primary,
          () => _goToTab(0),
        ),
        _ServiceItem(
          'Notes',
          Icons.sticky_note_2_outlined,
          AppColors.warningOrange,
          () => Get.toNamed(Routes.notes),
        ),
        _ServiceItem(
          'Chat',
          Icons.chat_bubble_outline_rounded,
          AppColors.primaryLight,
          () => Get.toNamed(Routes.chat),
        ),
      ],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('All services')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.gapSm,
          AppDimens.screenPadding,
          AppDimens.gapXxl,
        ),
        children: [
          for (final entry in sections.entries) ...[
            SectionHeader(title: entry.key),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppDimens.gapMd,
              crossAxisSpacing: AppDimens.gapMd,
              childAspectRatio: 0.95,
              children: [
                for (final item in entry.value)
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.gapSm),
                    onTap: item.onTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconBadge(icon: item.icon, color: item.color, size: 48),
                        const SizedBox(height: AppDimens.gapMd),
                        Text(
                          item.label,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.gapXl),
          ],
        ],
      ),
    );
  }
}
