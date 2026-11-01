import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../widgets/student_detail_widget.dart';
import '../widgets/usage_hero_card.dart';

/// A student's usage & trends: day picker, the day's total against the
/// allowance, and the charts. Opened from the student's overview
/// ([StudentUsageScreen]); reads only that student's controller.
class StudentUsageBody extends StudentDetailWidget {
  const StudentUsageBody({super.key, required super.controller});

  // The old page rebuilt this whenever any observable it reads changed; keep
  // that now that it is a widget of its own.
  @override
  Widget build(BuildContext context) => Obx(() => _buildDetail(context));

  Widget _buildDetail(BuildContext context) {
    final firstLoad =
        controller.isLoading.value &&
        controller.totalMinutesToday.value == 0 &&
        controller.historyRecords.isEmpty;
    if (firstLoad) {
      return const Column(
        children: [
          SkeletonLoader(
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          SizedBox(height: 12),
          SkeletonLoader(
            height: 72,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          SizedBox(height: 12),
          SkeletonLoader(
            height: 180,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          SizedBox(height: 12),
          SkeletonLoader(
            height: 220,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDaySelectorBar(context),
        const SizedBox(height: 8),

        // How much, against the allowance
        UsageHeroCard(controller: controller),
        const SizedBox(height: 12),

        // Trends
        _buildScreenTimeAnalyticsGraph(context),
        const SizedBox(height: 12),

        _buildDetailedAnalyticsCard(context),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7.5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0284C7)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0284C7,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
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
                  final now = DateTime.now();
                  final first = now.subtract(const Duration(days: 90));
                  var initial = DateTime.tryParse(selectedDate) ?? now;
                  if (initial.isAfter(now)) initial = now;
                  if (initial.isBefore(first)) initial = first;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: first,
                    lastDate: now,
                  );
                  if (picked != null) {
                    final pickedStr =
                        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    controller.selectDate(pickedStr);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 15,
                        color: Color(0xFF0284C7),
                      ),
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
      final chartMaxY =
          (maxHours <= 2.0 ? 3.0 : (maxHours + 1.5).ceilToDouble()).clamp(
            3.0,
            24.0,
          );

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
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFF0284C7),
                    size: 20,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 12,
                        color: Color(0xFF0284C7),
                      ),
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
                _buildLegendItem(
                  const Color(0xFFEF4444),
                  'Night Curfew (11PM - 5AM)',
                ),
                _buildLegendItem(
                  const Color(0xFF0284C7).withValues(alpha: 0.25),
                  'Selected Bar',
                  isBorder: true,
                ),
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
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
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
                            onTap: () =>
                                controller.selectDate(p['date'] as String),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isTod ? 'Today' : (p['dayLabel'] as String),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSel
                                          ? const Color(0xFF0284C7)
                                          : (isTod
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF64748B)),
                                    ),
                                  ),
                                  Text(
                                    p['dateLabel'] as String,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSel
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF94A3B8),
                                      fontWeight: isSel
                                          ? FontWeight.w600
                                          : FontWeight.normal,
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
                      if (event is FlTapUpEvent &&
                          response != null &&
                          response.spot != null) {
                        final idx = response.spot!.touchedBarGroupIndex;
                        if (idx >= 0 && idx < points.length) {
                          controller.selectDate(points[idx]['date'] as String);
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF0F172A),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final p = points[groupIndex];
                        final totMin = (p['totalMinutes'] is num)
                            ? (p['totalMinutes'] as num).toInt()
                            : (int.tryParse(
                                    p['totalMinutes']?.toString() ?? '',
                                  ) ??
                                  0);
                        final nightMin = (p['nightMinutes'] is num)
                            ? (p['nightMinutes'] as num).toInt()
                            : (int.tryParse(
                                    p['nightMinutes']?.toString() ?? '',
                                  ) ??
                                  0);
                        final dateStr =
                            (p['dateLabel'] ??
                                    p['shortDate'] ??
                                    p['date'] ??
                                    '')
                                .toString();
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
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              rodStackItems: nightH > 0
                                  ? [
                                      BarChartRodStackItem(
                                        0,
                                        daytimeH,
                                        baseColor,
                                      ),
                                      BarChartRodStackItem(
                                        daytimeH,
                                        totalH,
                                        const Color(0xFFEF4444),
                                      ),
                                    ]
                                  : [
                                      BarChartRodStackItem(
                                        0,
                                        displayH,
                                        totalH <= 0
                                            ? const Color(0xFFCBD5E1)
                                            : baseColor,
                                      ),
                                    ],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: chartMaxY,
                                color: isSel
                                    ? const Color(
                                        0xFF0284C7,
                                      ).withValues(alpha: 0.08)
                                    : const Color(
                                        0xFF0F172A,
                                      ).withValues(alpha: 0.02),
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
            border: isBorder
                ? Border.all(color: const Color(0xFF0284C7), width: 1.5)
                : null,
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
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Color(0xFF0284C7),
                    size: 20,
                  ),
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
                    subtext: nightMin > 0
                        ? 'Late night activity'
                        : 'Curfew respected',
                    icon: Icons.nightlight_round,
                    color: nightMin > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF10B981),
                    bgColor: nightMin > 0
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderColor: nightMin > 0
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF86EFAC),
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
                    subtext: score >= 75
                        ? 'Healthy balance'
                        : (score >= 50
                              ? 'Moderate usage'
                              : 'High screen usage'),
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
                    color: isLocked
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0284C7),
                    bgColor: isLocked
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFE0F2FE),
                    borderColor: isLocked
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFBAE6FD),
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
                  totalCatMinutes > 0
                      ? '${totalCatMinutes ~/ 60}h ${totalCatMinutes % 60}m logged'
                      : 'No apps logged',
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
                        children: cats.entries.where((e) => e.value > 0).map((
                          entry,
                        ) {
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
                final pct = totalCatMinutes > 0
                    ? ((mins / totalCatMinutes) * 100).round()
                    : 0;
                final color = _getCategoryColor(catName);
                final icon = _getCategoryIcon(catName);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
