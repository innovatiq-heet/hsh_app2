import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import 'complain_home_screen.dart';
import 'complain_management_screen.dart';
import 'complain_module_controller.dart';
import 'complain_orders_screen.dart';

class ComplainModuleScreen extends GetView<ComplainModuleController> {
  const ComplainModuleScreen({super.key});

  static const _tabs = [
    ComplainOrdersScreen(),
    ComplainManagementScreen(),
    ComplainHomeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(
        () => IndexedStack(
          index: controller.tabIndex.value,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Obx(
        () => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: controller.tabIndex.value,
            onDestinationSelected: controller.changeTab,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primarySoft,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon:
                    Icon(Icons.assignment_rounded, color: AppColors.primary),
                label: 'Desk',
              ),
              NavigationDestination(
                icon: Icon(Icons.meeting_room_outlined),
                selectedIcon:
                    Icon(Icons.meeting_room_rounded, color: AppColors.primary),
                label: 'Inspect',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon:
                    Icon(Icons.insights_rounded, color: AppColors.primary),
                label: 'Overview',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
