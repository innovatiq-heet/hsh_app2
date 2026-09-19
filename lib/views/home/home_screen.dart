import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../attendance/attendance_screen.dart';
import '../complaints/complaints_screen.dart';
import '../laundry/laundry_screen.dart';
import '../shared/widgets/fade_indexed_stack.dart';
import '../shared/widgets/floating_nav_bar.dart';
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

  static const _items = [
    FloatingNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
    FloatingNavItem(
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent_rounded,
      label: 'Complaints',
    ),
    FloatingNavItem(
      icon: Icons.local_laundry_service_outlined,
      activeIcon: Icons.local_laundry_service_rounded,
      label: 'Laundry',
    ),
    FloatingNavItem(
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      label: 'Attendance',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // extendBody lets tab content scroll beneath the frosted nav bar; the
    // tabs' own Scaffolds inherit the bar's height as bottom padding, so
    // their FABs still sit above it.
    return Scaffold(
      extendBody: true,
      body: Obx(
        () => FadeIndexedStack(
          index: controller.tabIndex.value,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Obx(
        () => FloatingNavBar(
          items: _items,
          currentIndex: controller.tabIndex.value,
          onChanged: controller.changeTab,
        ),
      ),
    );
  }
}
