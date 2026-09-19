import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../attendance/attendance_screen.dart';
import '../complaints/complaints_screen.dart';
import '../laundry/laundry_screen.dart';
import '../student_profile/student_profile_screen.dart';
import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  static const _tabs = [
    StudentProfileScreen(),
    ComplaintsScreen(),
    LaundryScreen(),
    AttendanceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(index: controller.tabIndex.value, children: _tabs),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Obx(
          () => NavigationBar(
            selectedIndex: controller.tabIndex.value,
            onDestinationSelected: controller.changeTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Icon(Icons.support_agent_outlined),
                selectedIcon: Icon(Icons.support_agent_rounded),
                label: 'Complaints',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_laundry_service_outlined),
                selectedIcon: Icon(Icons.local_laundry_service_rounded),
                label: 'Laundry',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: 'Attendance',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
