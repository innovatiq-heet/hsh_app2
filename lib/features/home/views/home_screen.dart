import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../attendance/views/attendance_screen.dart';
// import '../../complaints/views/complaints_screen.dart';  // Commented out — feature disabled for now
// import '../../laundry/views/laundry_screen.dart';          // Commented out — feature disabled for now
import '../../student_profile/views/student_profile_screen.dart';
import '../controllers/home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  static const _tabs = [
    StudentProfileScreen(),
    // ComplaintsScreen(),   // Commented out — feature disabled for now
    // LaundryScreen(),      // Commented out — feature disabled for now
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
                label: 'Dashboard',
              ),
              // NavigationDestination(                          // Commented out — feature disabled for now
              //   icon: Icon(Icons.support_agent_outlined),
              //   selectedIcon: Icon(Icons.support_agent_rounded),
              //   label: 'Complaints',
              // ),
              // NavigationDestination(                          // Commented out — feature disabled for now
              //   icon: Icon(Icons.local_laundry_service_outlined),
              //   selectedIcon: Icon(Icons.local_laundry_service_rounded),
              //   label: 'Laundry',
              // ),
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

