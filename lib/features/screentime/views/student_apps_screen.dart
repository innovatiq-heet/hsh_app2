import 'package:flutter/material.dart';
import '../controllers/student_detail_controller.dart';
import '../widgets/app_usage_card.dart';
import '../widgets/screen_time_page.dart';

/// Every app on the student's phone for today: time used, and a block or
/// time-limit control on each. Its own screen, opened from the overview.
class StudentAppsScreen extends StatelessWidget {
  final StudentDetailController controller;
  const StudentAppsScreen({super.key, required this.controller});

  static Future<void> open(BuildContext context, StudentDetailController controller) =>
      ScreenTimePage.push(context, StudentAppsScreen(controller: controller));

  @override
  Widget build(BuildContext context) {
    return ScreenTimePage(
      title: 'Apps',
      subtitle: ScreenTimePage.studentLine(controller.selectedStudent.value),
      onRefresh: controller.refreshAll,
      body: AppUsageCard(controller: controller),
    );
  }
}
