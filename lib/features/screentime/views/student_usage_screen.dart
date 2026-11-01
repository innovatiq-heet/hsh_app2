import 'package:flutter/material.dart';
import '../controllers/student_detail_controller.dart';
import '../widgets/screen_time_page.dart';
import '../widgets/student_usage_body.dart';

/// "Usage & trends" for one student: day picker, the day's total against the
/// allowance, and the charts. Its own screen, opened from the student's
/// overview. (The app list and the history have their own screens.)
class StudentUsageScreen extends StatefulWidget {
  final StudentDetailController controller;
  const StudentUsageScreen({super.key, required this.controller});

  static Future<void> open(BuildContext context, StudentDetailController controller) =>
      ScreenTimePage.push(context, StudentUsageScreen(controller: controller));

  @override
  State<StudentUsageScreen> createState() => _StudentUsageScreenState();
}

class _StudentUsageScreenState extends State<StudentUsageScreen> {
  StudentDetailController get controller => widget.controller;

  @override
  void dispose() {
    // A past day picked here must not leak into the overview, which is always
    // about today.
    if (!controller.isClosed && !controller.isTodaySelected) {
      controller.selectDate(controller.todayDateStr);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTimePage(
      title: 'Usage & trends',
      subtitle: ScreenTimePage.studentLine(controller.selectedStudent.value),
      onRefresh: controller.refreshAll,
      body: StudentUsageBody(controller: controller),
    );
  }
}
