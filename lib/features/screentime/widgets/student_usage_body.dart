import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/student_detail_controller.dart';
import '../controllers/usage_analytics.dart';
import '../views/student_apps_screen.dart';
import 'top_apps_card.dart';
import 'usage/usage_category_card.dart';
import 'usage/usage_insights_card.dart';
import 'usage/usage_range_selector.dart';
import 'usage/usage_rhythm_card.dart';
import 'usage/usage_summary_card.dart';
import 'usage/usage_trend_chart.dart';

/// A student's usage analysis: the selected day against the period, a daily
/// chart, what stands out, where the time went, the weekly rhythm and the top
/// apps. Opened from the overview ([StudentUsageScreen]); reads only that
/// student's controller.
class StudentUsageBody extends StatefulWidget {
  final StudentDetailController controller;
  const StudentUsageBody({super.key, required this.controller});

  @override
  State<StudentUsageBody> createState() => _StudentUsageBodyState();
}

class _StudentUsageBodyState extends State<StudentUsageBody> {
  int _days = 7;

  StudentDetailController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever an observable read below changes (history, today's
    // totals, the selected day, the limit ...).
    return Obx(() {
      final firstLoad = controller.isLoading.value &&
          controller.totalMinutesToday.value == 0 &&
          controller.historyRecords.isEmpty;
      if (firstLoad) return const _Skeleton();

      final analytics = UsageAnalytics.fromPoints(
        controller.usagePoints(_days),
        limit: controller.dailyLimitMinutes.value,
      );
      final selected = controller.effectiveSelectedDate;
      final categories = controller.categoryMinutes;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UsageRangeSelector(days: _days, onChanged: (d) => setState(() => _days = d)),
          const SizedBox(height: AppDimens.gapMd),
          UsageSummaryCard(
            analytics: analytics,
            date: selected,
            isToday: controller.isTodaySelected,
            minutes: controller.selectedDayTotalMinutes,
            night: controller.selectedDayNightMinutes,
            onBackToToday: () => controller.selectDate(controller.todayDateStr),
          ),
          const SizedBox(height: AppDimens.gapMd),
          UsageTrendChart(
            analytics: analytics,
            selectedDate: selected,
            onSelectDate: controller.selectDate,
          ),
          const SizedBox(height: AppDimens.gapMd),
          UsageInsightsCard(insights: buildUsageInsights(analytics, categories: categories)),
          const SizedBox(height: AppDimens.gapMd),
          UsageCategoryCard(categories: categories),
          const SizedBox(height: AppDimens.gapMd),
          UsageRhythmCard(analytics: analytics),
          const SizedBox(height: AppDimens.gapMd),
          TopAppsCard(
            controller: controller,
            onSeeAll: () => StudentAppsScreen.open(context, controller),
          ),
        ],
      );
    });
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoader(height: 44, borderRadius: BorderRadius.all(Radius.circular(999))),
        SizedBox(height: 12),
        SkeletonLoader(height: 190, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: 12),
        SkeletonLoader(height: 280, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: 12),
        SkeletonLoader(height: 160, borderRadius: BorderRadius.all(Radius.circular(20))),
      ],
    );
  }
}
