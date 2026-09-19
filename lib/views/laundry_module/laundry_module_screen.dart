import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_routes.dart';
import '../../storage/session_store.dart';
import 'laundry_home_screen.dart';
import 'laundry_management_screen.dart';
import 'laundry_module_controller.dart';
import 'laundry_orders_screen.dart';

class LaundryModuleScreen extends GetView<LaundryModuleController> {
  const LaundryModuleScreen({super.key});

  static const _tabs = [
    LaundryHomeScreen(),
    LaundryOrdersScreen(),
    LaundryManagementScreen(),
  ];

  static const _titles = ['Laundry desk', 'Orders', 'Recharge'];

  Future<void> _logout() async {
    await SessionStore.instance.clear();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_titles[controller.tabIndex.value])),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(
        () => IndexedStack(index: controller.tabIndex.value, children: _tabs),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Recharge',
            ),
          ],
        ),
      ),
    );
  }
}
