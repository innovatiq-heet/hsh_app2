import 'package:flutter/material.dart';
import '../../../core/constants/app_dimens.dart';
import '../controllers/student_detail_controller.dart';
import '../widgets/app_requests_banner.dart';
import '../widgets/screen_time_page.dart';
import '../widgets/selected_day_card.dart';
import '../widgets/top_apps_card.dart';
import '../widgets/usage_calendar_card.dart';
import 'student_apps_screen.dart';

/// Pending app requests, and a month calendar of the student's screen time:
/// tap a date to see that day's total and its most used apps.
class StudentHistoryScreen extends StatefulWidget {
  final StudentDetailController controller;
  const StudentHistoryScreen({super.key, required this.controller});

  static Future<void> open(BuildContext context, StudentDetailController controller) =>
      ScreenTimePage.push(context, StudentHistoryScreen(controller: controller));

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  StudentDetailController get controller => widget.controller;

  @override
  void dispose() {
    // A day picked on the calendar must not leak into the overview, which is
    // always about today.
    if (!controller.isClosed && !controller.isTodaySelected) {
      controller.selectDate(controller.todayDateStr);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTimePage(
      title: 'Requests & history',
      subtitle: ScreenTimePage.studentLine(controller.selectedStudent.value),
      onRefresh: controller.refreshAll,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hides itself when nothing is pending.
          AppRequestsBanner(host: controller),
          UsageCalendarCard(controller: controller),
          const SizedBox(height: AppDimens.gapMd),
          SelectedDayCard(controller: controller),
          const SizedBox(height: AppDimens.gapMd),
          TopAppsCard(
            controller: controller,
            onSeeAll: () => StudentAppsScreen.open(context, controller),
          ),
        ],
      ),
    );
  }
}
