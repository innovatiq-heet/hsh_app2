import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/student_screen_time_controller.dart';
import '../widgets/app_usage_card.dart';
import '../widgets/history_card.dart';
import '../widgets/live_status_card.dart';
import '../widgets/parental_controls_card.dart';
import '../widgets/student_directory_view.dart';
import '../widgets/usage_hero_card.dart';

/// Warden's screen-time console. Directory of students first; tapping one
/// opens the detail page: what the phone is doing now, today's total against
/// the allowance, the controls, then per-app usage and trends.
class StudentScreenTimeScreen extends GetView<StudentScreenTimeController> {
  const StudentScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(() {
        final selected = controller.selectedStudent.value;
        final direct = controller.openedWithDirectTarget.value;

        return RefreshIndicator(
          onRefresh: controller.refreshAll,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverGradientHeader(
                overline: selected != null ? 'PARENTAL CONTROL' : null,
                title: selected != null ? (selected['name'] ?? 'Student') : 'Screen Time',
                subtitle: selected != null
                    ? 'Room ${selected['room'] ?? 'N/A'} • Aadhar ${selected['aadhar'] ?? ''}'
                    : 'Live device activity & parental controls',
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: selected != null && !direct ? 'Back to directory' : 'Back',
                  onPressed: () {
                    if (selected != null && !direct) {
                      controller.clearSelectedStudent();
                    } else {
                      Get.back();
                    }
                  },
                ),
                actions: [
                  if (selected != null && direct)
                    HeaderIconButton(
                      icon: Icons.people_alt_outlined,
                      tooltip: 'All students',
                      onPressed: () {
                        controller.openedWithDirectTarget.value = false;
                        controller.clearSelectedStudent();
                      },
                    ),
                  HeaderIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onPressed: controller.refreshAll,
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapLg,
                  AppDimens.screenPadding,
                  AppDimens.gapXxl,
                ),
                sliver: SliverToBoxAdapter(
                  child: selected == null
                      ? const StudentDirectoryView()
                      : _buildDetail(context),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final firstLoad = controller.isLoading.value &&
        controller.totalMinutesToday.value == 0 &&
        controller.historyRecords.isEmpty;
    if (firstLoad) {
      return const Column(
        children: [
          SkeletonLoader(height: 36, borderRadius: BorderRadius.all(Radius.circular(18))),
          SizedBox(height: AppDimens.gapMd),
          SkeletonLoader(height: 72, borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusLg))),
          SizedBox(height: AppDimens.gapMd),
          SkeletonLoader(height: 180, borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusLg))),
          SizedBox(height: AppDimens.gapMd),
          SkeletonLoader(height: 220, borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusLg))),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDaySelectorBar(context),
        const SizedBox(height: AppDimens.gapSm),

        // 1. What's happening now
        const LiveStatusCard(),
        const SizedBox(height: AppDimens.gapMd),

        // 2. How much, against the allowance
        const UsageHeroCard(),
        const SizedBox(height: AppDimens.gapMd),

        // 3. What the warden can do about it
        const ParentalControlsCard(),
        const SizedBox(height: AppDimens.gapMd),

        // 4. Where the time went
        const AppUsageCard(),
        const SizedBox(height: AppDimens.gapMd),

        // 5. Trends
        _buildScreenTimeAnalyticsGraph(context),
        const SizedBox(height: AppDimens.gapMd),
        _buildDetailedAnalyticsCard(context),
        const SizedBox(height: AppDimens.gapMd),

        const HistoryCard(),
      ],
    );
  }

  Widget _buildDaySelectorBar(BuildContext context) {
    return Obx(() {
      final days = controller.availableDays;
      final selectedDate = controller.effectiveSelectedDate;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...days.map((d) {
                final dateStr = d['date']!;
                final label = d['label']!;
                final isSelected = selectedDate == dateStr;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => controller.selectDate(dateStr),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Pick Date Calendar button
              GestureDetector(
                onTap: () async {
                  final initial = DateTime.tryParse(selectedDate) ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    final pickedStr =
                        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    controller.selectDate(pickedStr);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Pick Date',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildScreenTimeAnalyticsGraph(BuildContext context) {
    return Obx(() {
      final points = controller.trendGraphPoints;
      if (points.isEmpty) return const SizedBox.shrink();

      double maxHours = 0;
      for (final p in points) {
        final val = p['hours'];
        final double h = (val is num)
            ? val.toDouble()
            : (double.tryParse(val?.toString() ?? '') ?? 0.0);
        if (h > maxHours) maxHours = h;
      }
      final chartMaxY = (maxHours <= 2.0 ? 3.0 : (maxHours + 1.5).ceilToDouble()).clamp(3.0, 24.0);

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('7-Day Usage Trend', style: AppTextStyles.subtitle),
                      Text(
                        'Tap any bar to inspect daily activity & curfew',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Interactive',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Legend Indicator
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _buildLegendItem(AppColors.primary, 'Daytime Usage'),
                _buildLegendItem(Colors.redAccent, 'Night Curfew (11PM - 5AM)'),
                _buildLegendItem(AppColors.primary.withValues(alpha: 0.25), 'Selected Bar', isBorder: true),
              ],
            ),
            const SizedBox(height: 20),

            // FlChart BarChart
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY > 6 ? 2 : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.12),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: chartMaxY > 6 ? 2 : 1,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              '${value.toInt()}h',
                              textAlign: TextAlign.right,
                              style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox.shrink();
                          final p = points[i];
                          final isSel = p['isSelected'] == true;
                          final isTod = p['isToday'] == true;

                          return GestureDetector(
                            onTap: () => controller.selectDate(p['date'] as String),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isTod ? 'Today' : (p['dayLabel'] as String),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel
                                          ? AppColors.primary
                                          : (isTod ? AppColors.textPrimary : AppColors.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    p['dateLabel'] as String,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSel ? AppColors.primary : Colors.grey.shade500,
                                      fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent && response != null && response.spot != null) {
                        final idx = response.spot!.touchedBarGroupIndex;
                        if (idx >= 0 && idx < points.length) {
                          controller.selectDate(points[idx]['date'] as String);
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF1E293B),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final p = points[groupIndex];
                        final totMin = (p['totalMinutes'] is num)
                            ? (p['totalMinutes'] as num).toInt()
                            : (int.tryParse(p['totalMinutes']?.toString() ?? '') ?? 0);
                        final nightMin = (p['nightMinutes'] is num)
                            ? (p['nightMinutes'] as num).toInt()
                            : (int.tryParse(p['nightMinutes']?.toString() ?? '') ?? 0);
                        final dateStr = (p['dateLabel'] ?? p['shortDate'] ?? p['date'] ?? '').toString();
                        final h = totMin ~/ 60;
                        final m = totMin % 60;

                        return BarTooltipItem(
                          '$dateStr\nTotal: ${h}h ${m}m\n${nightMin > 0 ? "Curfew: ${nightMin}m ⚠️\n" : ""}(Tap to view)',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < points.length; i++) ...[
                      () {
                        final p = points[i];
                        final isSel = p['isSelected'] == true;
                        final hRaw = p['hours'];
                        final totalH = (hRaw is num)
                            ? hRaw.toDouble()
                            : (double.tryParse(hRaw?.toString() ?? '') ?? 0.0);
                        final nRaw = p['nightHours'];
                        final nightH = (nRaw is num)
                            ? nRaw.toDouble()
                            : (double.tryParse(nRaw?.toString() ?? '') ?? 0.0);
                        final displayH = totalH <= 0 ? 0.08 : totalH;
                        final daytimeH = (totalH - nightH).clamp(0.0, totalH);

                        final baseColor = isSel
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.7);

                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: displayH,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                              rodStackItems: nightH > 0
                                  ? [
                                      BarChartRodStackItem(0, daytimeH, baseColor),
                                      BarChartRodStackItem(daytimeH, totalH, Colors.redAccent),
                                    ]
                                  : [
                                      BarChartRodStackItem(0, displayH, totalH <= 0 ? Colors.grey.shade300 : baseColor),
                                    ],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: chartMaxY,
                                color: isSel
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.02),
                              ),
                            ),
                          ],
                        );
                      }(),
                    ],
                  ],
                ),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLegendItem(Color color, String label, {bool isBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: isBorder ? Border.all(color: AppColors.primary, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildDetailedAnalyticsCard(BuildContext context) {
    return Obx(() {
      final avgMin = controller.averageDailyMinutes;
      final nightMin = controller.selectedDayNightMinutes;
      final score = controller.complianceScore;
      final isLocked = controller.isDeviceLocked.value;
      final blockedCount = controller.blockedPackages.length;
      final cats = controller.categoryMinutes;
      final isToday = controller.isTodaySelected;

      // Color scheme for score
      Color scoreColor = const Color(0xFF10B981); // green
      if (score < 50) {
        scoreColor = const Color(0xFFEF4444); // red
      } else if (score < 75) {
        scoreColor = const Color(0xFFF59E0B); // amber
      }

      int totalCatMinutes = 0;
      cats.forEach((k, v) => totalCatMinutes += v);

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Screen Time Behavioral Analysis', style: AppTextStyles.subtitle),
                      Text(
                        'Pattern evaluation & hostel discipline score',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2x2 Grid of Key Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: '7-Day Daily Avg',
                    value: '${avgMin ~/ 60}h ${avgMin % 60}m',
                    subtext: 'Weekly mean usage',
                    icon: Icons.timelapse_rounded,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Night Curfew',
                    value: '$nightMin mins',
                    subtext: nightMin > 0 ? 'Late night activity' : 'Curfew respected',
                    icon: Icons.nightlight_round,
                    color: nightMin > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    bgColor: nightMin > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Focus Discipline',
                    value: '$score%',
                    subtext: score >= 75 ? 'Healthy balance' : (score >= 50 ? 'Moderate usage' : 'High screen usage'),
                    icon: Icons.verified_user_rounded,
                    color: scoreColor,
                    bgColor: scoreColor.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Policy Controls',
                    value: isLocked ? 'Device Locked' : '$blockedCount Blocked',
                    subtext: 'Auto-kick enforced',
                    icon: isLocked ? Icons.lock_rounded : Icons.shield_rounded,
                    color: isLocked ? const Color(0xFFDC2626) : AppColors.primary,
                    bgColor: isLocked ? const Color(0xFFFEF2F2) : AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // App Categories Breakdown Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category Usage (${isToday ? 'Today' : 'Selected Day'})',
                  style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  totalCatMinutes > 0 ? '${totalCatMinutes ~/ 60}h ${totalCatMinutes % 60}m logged' : 'No apps logged',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Segmented Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: totalCatMinutes == 0
                    ? Container(color: Colors.grey.shade200)
                    : Row(
                        children: cats.entries.where((e) => e.value > 0).map((entry) {
                          final flex = entry.value;
                          final color = _getCategoryColor(entry.key);
                          return Expanded(
                            flex: flex,
                            child: Container(
                              color: color,
                              margin: const EdgeInsets.only(right: 1.5),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Category Chips Wrap
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats.entries.map((e) {
                final catName = e.key;
                final mins = e.value;
                final pct = totalCatMinutes > 0 ? ((mins / totalCatMinutes) * 100).round() : 0;
                final color = _getCategoryColor(catName);
                final icon = _getCategoryIcon(catName);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 5),
                      Text(
                        catName,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${mins ~/ 60 > 0 ? "${mins ~/ 60}h " : ""}${mins % 60}m ($pct%)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Social Media':
        return const Color(0xFFE1306C);
      case 'Entertainment':
        return const Color(0xFFE50914);
      case 'Gaming':
        return const Color(0xFF8B5CF6);
      case 'Study & Tools':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Social Media':
        return Icons.chat_bubble_outline_rounded;
      case 'Entertainment':
        return Icons.smart_display_outlined;
      case 'Gaming':
        return Icons.sports_esports_outlined;
      case 'Study & Tools':
        return Icons.school_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }
}
