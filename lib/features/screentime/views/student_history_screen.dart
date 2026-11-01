import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../controllers/student_detail_controller.dart';
import '../widgets/app_requests_banner.dart';
import '../widgets/history_card.dart';
import '../widgets/screen_time_page.dart';

/// Pending app requests from the student, and the day-by-day history.
class StudentHistoryScreen extends StatelessWidget {
  final StudentDetailController controller;
  const StudentHistoryScreen({super.key, required this.controller});

  static Future<void> open(BuildContext context, StudentDetailController controller) =>
      ScreenTimePage.push(context, StudentHistoryScreen(controller: controller));

  @override
  Widget build(BuildContext context) {
    return ScreenTimePage(
      title: 'Requests & history',
      subtitle: ScreenTimePage.studentLine(controller.selectedStudent.value),
      onRefresh: controller.refreshAll,
      body: Obx(() {
        final noRequests = controller.pendingAppRequests.isEmpty;
        final noHistory = controller.historyRecords.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppRequestsBanner(host: controller),
            HistoryCard(controller: controller),
            if (noRequests && noHistory)
              const AppCard(
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Nothing here yet',
                  message: 'App requests and daily history appear once the phone has reported in.',
                ),
              ),
          ],
        );
      }),
    );
  }
}
