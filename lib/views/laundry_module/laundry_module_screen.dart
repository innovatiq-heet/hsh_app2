import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import 'laundry_home_screen.dart';
import 'laundry_management_screen.dart';
import 'laundry_module_controller.dart';
import 'laundry_orders_screen.dart';

class LaundryModuleScreen extends GetView<LaundryModuleController> {
  const LaundryModuleScreen({super.key});

  static const _tabs = [
    LaundryOrdersScreen(),
    LaundryManagementScreen(),
    LaundryHomeScreen(),
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
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                label: 'Recharge',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded, color: AppColors.primary),
                label: 'Overview',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
