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
      body: Obx(() {
        final currentIndex = controller.tabIndex.value;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: _tabs[currentIndex],
          ),
        );
      }),
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
