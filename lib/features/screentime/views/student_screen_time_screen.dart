import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/student_screen_time_controller.dart';
import '../widgets/app_usage_card.dart';
import '../widgets/history_card.dart';
import '../widgets/live_status_card.dart';
import '../widgets/parental_controls_card.dart';
import '../widgets/student_directory_view.dart';
import '../widgets/usage_hero_card.dart';

/// Warden's screen-time console styled with the signature deep navy header,
/// sky-blue accents, and slate card styling from the Phonebook screen.
class StudentScreenTimeScreen extends GetView<StudentScreenTimeController> {
  const StudentScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Obx(() {
          final selected = controller.selectedStudent.value;

          return RefreshIndicator(
            onRefresh: controller.refreshAll,
            color: const Color(0xFF0284C7),
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ScreenTimeHeaderDelegate(
                    controller: controller,
                    topPadding: MediaQuery.of(context).padding.top,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
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
      ),
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
          SizedBox(height: 12),
          SkeletonLoader(height: 72, borderRadius: BorderRadius.all(Radius.circular(16))),
          SizedBox(height: 12),
          SkeletonLoader(height: 180, borderRadius: BorderRadius.all(Radius.circular(16))),
          SizedBox(height: 12),
          SkeletonLoader(height: 220, borderRadius: BorderRadius.all(Radius.circular(16))),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDaySelectorBar(context),
        const SizedBox(height: 8),

        // 1. What's happening now
        const LiveStatusCard(),
        const SizedBox(height: 12),

        // 2. How much, against the allowance
        const UsageHeroCard(),
        const SizedBox(height: 12),

        // 3. What the warden can do about it
        const ParentalControlsCard(),
        const SizedBox(height: 12),

        // 4. Where the time went
        const AppUsageCard(),
        const SizedBox(height: 12),

        // 5. Trends
        _buildScreenTimeAnalyticsGraph(context),
        const SizedBox(height: 12),
        _buildDetailedAnalyticsCard(context),
        const SizedBox(height: 12),

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
          physics: const BouncingScrollPhysics(),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0284C7) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                  blurRadius: 8,
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
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF0284C7)),
                      SizedBox(width: 5),
                      Text(
                        'Pick Date',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
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
      if (points.isEmpty) {
        return const SizedBox.shrink();
      }

      double maxHours = 0;
      for (final p in points) {
        final val = p['hours'];
        final double h = (val is num)
            ? val.toDouble()
            : (double.tryParse(val?.toString() ?? '') ?? 0.0);
        if (h > maxHours) {
          maxHours = h;
        }
      }
      final chartMaxY = (maxHours <= 2.0 ? 3.0 : (maxHours + 1.5).ceilToDouble()).clamp(3.0, 24.0);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '7-Day Usage Trend',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap any bar to inspect daily activity & curfew',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFF0284C7)),
                      SizedBox(width: 4),
                      Text(
                        'Interactive',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
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
                _buildLegendItem(const Color(0xFF0284C7), 'Daytime Usage'),
                _buildLegendItem(const Color(0xFFEF4444), 'Night Curfew (11PM - 5AM)'),
                _buildLegendItem(const Color(0xFF0284C7).withValues(alpha: 0.25), 'Selected Bar', isBorder: true),
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
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: Color(0xFFE2E8F0),
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
                          if (value == 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              '${value.toInt()}h',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
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
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
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
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel
                                          ? const Color(0xFF0284C7)
                                          : (isTod ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                  Text(
                                    p['dateLabel'] as String,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSel ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
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
                      getTooltipColor: (_) => const Color(0xFF0F172A),
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
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF0284C7).withValues(alpha: 0.7);

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
                                      BarChartRodStackItem(daytimeH, totalH, const Color(0xFFEF4444)),
                                    ]
                                  : [
                                      BarChartRodStackItem(0, displayH, totalH <= 0 ? const Color(0xFFCBD5E1) : baseColor),
                                    ],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: chartMaxY,
                                color: isSel
                                    ? const Color(0xFF0284C7).withValues(alpha: 0.08)
                                    : const Color(0xFF0F172A).withValues(alpha: 0.02),
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
            border: isBorder ? Border.all(color: const Color(0xFF0284C7), width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
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
      Color scoreBg = const Color(0xFFF0FDF4);
      Color scoreBorder = const Color(0xFF86EFAC);
      if (score < 50) {
        scoreColor = const Color(0xFFDC2626); // red
        scoreBg = const Color(0xFFFEF2F2);
        scoreBorder = const Color(0xFFFCA5A5);
      } else if (score < 75) {
        scoreColor = const Color(0xFFD97706); // amber
        scoreBg = const Color(0xFFFEF3C7);
        scoreBorder = const Color(0xFFFDE68A);
      }

      int totalCatMinutes = 0;
      cats.forEach((k, v) => totalCatMinutes += v);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screen Time Behavioral Analysis',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pattern evaluation & hostel discipline score',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
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
                    color: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFE0F2FE),
                    borderColor: const Color(0xFFBAE6FD),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Night Curfew',
                    value: '$nightMin mins',
                    subtext: nightMin > 0 ? 'Late night activity' : 'Curfew respected',
                    icon: Icons.nightlight_round,
                    color: nightMin > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                    bgColor: nightMin > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                    borderColor: nightMin > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
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
                    bgColor: scoreBg,
                    borderColor: scoreBorder,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Policy Controls',
                    value: isLocked ? 'Device Locked' : '$blockedCount Blocked',
                    subtext: 'Auto-kick enforced',
                    icon: isLocked ? Icons.lock_rounded : Icons.shield_rounded,
                    color: isLocked ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                    bgColor: isLocked ? const Color(0xFFFEF2F2) : const Color(0xFFE0F2FE),
                    borderColor: isLocked ? const Color(0xFFFCA5A5) : const Color(0xFFBAE6FD),
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
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  totalCatMinutes > 0 ? '${totalCatMinutes ~/ 60}h ${totalCatMinutes % 60}m logged' : 'No apps logged',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
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
                    ? Container(color: const Color(0xFFE2E8F0))
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
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 5),
                      Text(
                        catName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${mins ~/ 60 > 0 ? "${mins ~/ 60}h " : ""}${mins % 60}m ($pct%)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
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
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
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
        return const Color(0xFFEA580C);
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

/// Collapsible shrinking deep navy header with luminous arcs, matching Phonebook header.
class _ScreenTimeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final StudentScreenTimeController controller;
  final double topPadding;

  _ScreenTimeHeaderDelegate({
    required this.controller,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + 62.0;

  @override
  double get maxExtent {
    final selected = controller.selectedStudent.value;
    return topPadding + (selected != null ? 190.0 : 180.0);
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular(
      (34.0 * (1.0 - progress)).clamp(0.0, 34.0),
    );

    final selected = controller.selectedStudent.value;
    final direct = controller.openedWithDirectTarget.value;
    final titleText = selected != null ? (selected['name'] ?? 'Student') : 'Screen Time';
    final subtitleText = selected != null
        ? 'Room ${selected['room'] ?? 'N/A'} • Aadhar ${selected['aadhar'] ?? ''}'
        : 'Live device activity & parental controls';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF03192E),
            Color(0xFF032B4F),
            Color(0xFF025A8D),
            Color(0xFF0369A1),
          ],
          stops: [0.0, 0.38, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        boxShadow: progress > 0.25
            ? [
                BoxShadow(
                  color: const Color(0xFF03192E).withValues(alpha: 0.22 * progress),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Luminous ambient orbs & arcs
            CustomPaint(painter: _HeaderOrbPainter()),

            // Top pinned navigation bar
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (selected != null && !direct) {
                          controller.clearSelectedStudent();
                        } else {
                          Get.back();
                        }
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Collapsed title that fades in on shrink
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // "All students" button if in direct target mode
                  if (selected != null && direct) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.openedWithDirectTarget.value = false;
                          controller.clearSelectedStudent();
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.people_alt_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Refresh button with loading spinner
                  Obx(() {
                    final isLoading = controller.isLoading.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLoading ? null : controller.refreshAll,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Expanded content (Amber dash, Overline, Large Title, Subtitle, Frosted pills)
            if (expandedOpacity > 0.02)
              Positioned(
                top: topPadding + 54,
                left: 20,
                right: 20,
                bottom: 12,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -progress * 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 28,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAAB78),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          selected != null
                              ? 'PARENTAL CONTROL'
                              : 'CAMPUS PARENTAL CONTROL & DEVICE USAGE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          titleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selected != null) ...[
                          const SizedBox(height: 8),
                          Obx(() {
                            final isOnline = controller.isOnline.value;
                            final isLocked = controller.isDeviceLocked.value;
                            return Row(
                              children: [
                                _headerPill(
                                  icon: isOnline
                                      ? Icons.circle_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  iconColor: isOnline
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF94A3B8),
                                  label: isOnline ? 'Online' : 'Offline',
                                ),
                                const SizedBox(width: 8),
                                _headerPill(
                                  icon: isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                  iconColor: isLocked
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFF34D399),
                                  label: isLocked ? 'Device Locked' : 'Unlocked',
                                ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerPill({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ScreenTimeHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.controller != controller;
  }
}

/// Custom painter for luminous concentric arcs and ambient light orbs in the header background.
class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-right luminous ambient glow
    final glowPaintRight = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.16),
          const Color(0xFF0284C7).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.90, size.height * 0.15),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.90, size.height * 0.15),
      size.width * 0.55,
      glowPaintRight,
    );

    // Bottom-left subtle ambient glow
    final glowPaintLeft = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.12),
          const Color(0xFF032B4F).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.10, size.height * 0.85),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.85),
      size.width * 0.45,
      glowPaintLeft,
    );

    // Elegant concentric arcs with smooth stroke
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.width * 0.38,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.width * 0.62,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.width * 0.86,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.92),
      size.width * 0.46,
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
