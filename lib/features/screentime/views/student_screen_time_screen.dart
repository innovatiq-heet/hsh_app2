import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/student_screen_time_controller.dart';
import '../widgets/app_brand_icon.dart';

class StudentScreenTimeScreen extends GetView<StudentScreenTimeController> {
  const StudentScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(() {
        final isLeader = controller.currentRole.value.canViewScreenTime;
        final selected = controller.selectedStudent.value;

        return RefreshIndicator(
          onRefresh: controller.refreshAll,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverGradientHeader(
                title: selected != null
                    ? (selected['name'] ?? 'Student Screen Time')
                    : 'Screen Time & Parental Control',
                subtitle: selected != null
                    ? 'Room ${selected['room'] ?? 'N/A'} • Aadhar ${selected['aadhar'] ?? ''}'
                    : 'Live device activity & app restrictions',
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: selected != null
                      ? (controller.openedWithDirectTarget.value ? 'Back' : 'Back to directory')
                      : 'Back',
                  onPressed: () {
                    if (selected != null && controller.openedWithDirectTarget.value) {
                      Get.back();
                    } else if (selected != null) {
                      controller.clearSelectedStudent();
                    } else {
                      Get.back();
                    }
                  },
                ),
                actions: [
                  HeaderIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onPressed: controller.refreshAll,
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  child: isLeader && selected == null
                      ? _buildStudentsDirectoryView()
                      : _buildDetailedScreenTimeView(context, isLeader, selected),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// Directory view for Leader: list of all students with live status & screen time
  Widget _buildStudentsDirectoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter Box
        AppCard(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Student Directory', style: AppTextStyles.title),
                  const Spacer(),
                  Obx(() => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${controller.filteredStudents.length} Students',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 12),
              Obx(() => TextField(
                controller: controller.searchFilterController,
                onChanged: controller.filterStudents,
                decoration: InputDecoration(
                  hintText: 'Search by name, room (e.g. A-204), or Aadhar...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: controller.searchText.value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            controller.searchFilterController.clear();
                            controller.filterStudents('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapMd),

        // Students List
        Obx(() {
          if (controller.isLoadingStudents.value) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final list = controller.filteredStudents;
          if (list.isEmpty) {
            return AppCard(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No students found', style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text(
                      'Try searching with a different name or room number.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final student = list[index];
              return _buildStudentListItem(student);
            },
          );
        }),
      ],
    );
  }

  /// Individual student list card in directory
  Widget _buildStudentListItem(dynamic student) {
    final name = (student['name'] ?? 'Student').toString();
    final room = (student['room'] ?? 'N/A').toString();
    final aadhar = (student['aadhar'] ?? '').toString();
    final isOnline = student['isOnline'] == true;
    final isScreenOn = student['isScreenOn'] == true;
    final totalMins = StudentScreenTimeController.toInt(student['totalScreenTimeMinutes']);
    final nightMins = StudentScreenTimeController.toInt(student['nightScreenTimeMinutes']);
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;

    // Status styling
    final Color statusColor = isOnline
        ? (isScreenOn ? Colors.green : Colors.amber)
        : Colors.grey.shade400;
    final String statusText = isOnline
        ? (isScreenOn ? 'Screen Active' : 'Standby')
        : 'Offline';

    // Initials for avatar
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'S';

    final aadharSuffix = aadhar.length >= 4 ? '...${aadhar.substring(aadhar.length - 4)}' : aadhar;

    return AppCard(
      onTap: () => controller.selectStudent(student),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar with status indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Student Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.mainBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        room,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (student['is_locked'] == true || student['isLocked'] == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.cancelledRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔒 Locked',
                          style: TextStyle(
                            color: AppColors.cancelledRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if ((student['blockedPackages'] is List &&
                            (student['blockedPackages'] as List).isNotEmpty) ||
                        (student['blocked_packages'] is List &&
                            (student['blocked_packages'] as List).isNotEmpty)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🛡️ Restricted',
                          style: TextStyle(
                            color: AppColors.warningOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      'Aadhar: $aadharSuffix',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Screen Time badge & Navigation Chevron
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hours}h ${mins}m',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              if (nightMins > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.nightlight_round, color: Colors.redAccent, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        '${nightMins}m night',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  /// Detailed screen time view for selected student
  Widget _buildDetailedScreenTimeView(BuildContext context, bool isLeader, dynamic selectedStudent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back bar if inspected by leader
        if (isLeader && selectedStudent != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                  tooltip: controller.openedWithDirectTarget.value ? 'Back' : 'Back to directory',
                  onPressed: () {
                    if (controller.openedWithDirectTarget.value) {
                      Get.back();
                    } else {
                      controller.clearSelectedStudent();
                    }
                  },
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedStudent['name'] ?? 'Selected Student',
                        style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Room ${selectedStudent['room'] ?? 'N/A'} • Aadhar ${selectedStudent['aadhar'] ?? ''}',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    controller.openedWithDirectTarget.value = false;
                    controller.clearSelectedStudent();
                  },
                  icon: const Icon(Icons.people_alt_outlined, size: 16),
                  label: const Text('All Students'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Loading state feedback while fetching telemetry
        if (controller.isLoading.value && controller.totalMinutesToday.value == 0) ...[
          const SizedBox(height: 36),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Fetching real-time device screen telemetry...',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 36),
        ] else ...[
          // Day Selector Bar (Today, Past History, Calendar)
          _buildDaySelectorBar(context),
          const SizedBox(height: AppDimens.gapSm),

          // Live Status or Archive Banner Card
          _buildLiveCard(),
          const SizedBox(height: AppDimens.gapMd),

          // Day Screen Time Hero Card (Shows stats for selected day)
          _buildDayUsageCard(),
          const SizedBox(height: AppDimens.gapMd),

          // 7-Day Interactive Screen Time & Curfew Trend Graph
          _buildScreenTimeAnalyticsGraph(context),
          const SizedBox(height: AppDimens.gapMd),

          // Comprehensive Analytics & Category Breakdown
          _buildDetailedAnalyticsCard(context),
          const SizedBox(height: AppDimens.gapMd),

          // Parental Safety & Remote Lock Card
          _buildParentalControlHeroCard(context),
          const SizedBox(height: AppDimens.gapMd),

          // Top Apps Breakdown & Restriction Controls
          _buildAppBreakdownCard(context),
          const SizedBox(height: AppDimens.gapMd),

          // Historical Daily Logs from API
          _buildHistoryCard(),
        ],
      ],
    );
  }

  Widget _buildLiveCard() {
    return Obx(() {
      final isToday = controller.isTodaySelected;
      if (!isToday) {
        final dStr = controller.effectiveSelectedDate;
        String formatted = dStr;
        try {
          formatted = DateFormat('EEE, d MMM yyyy').format(DateTime.parse(dStr));
        } catch (_) {}

        return AppCard(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Historical Day Record', style: AppTextStyles.title),
                    Text(
                      'Viewing phone activity logs for $formatted',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Archive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
        );
      }

      final online = controller.isOnline.value;
      final screenOn = controller.isScreenOn.value;
      final app = controller.currentApp.value;

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? (screenOn ? Colors.green : Colors.amber) : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online
                        ? (screenOn ? 'Screen Active Now' : 'Device Idle (Standby)')
                        : 'Device Offline',
                    style: AppTextStyles.title,
                  ),
                  if (app.isNotEmpty && app != 'Idle')
                    Text(
                      'Foreground: $app',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
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

  Widget _buildDayUsageCard() {
    return Obx(() {
      final isToday = controller.isTodaySelected;
      final total = controller.selectedDayTotalMinutes;
      final hours = total ~/ 60;
      final minutes = total % 60;
      final night = controller.selectedDayNightMinutes;

      String dayTitle = "TODAY'S SCREEN TIME";
      if (!isToday) {
        final dStr = controller.effectiveSelectedDate;
        try {
          final parsed = DateTime.parse(dStr);
          final now = DateTime.now();
          final yest = now.subtract(const Duration(days: 1));
          if (parsed.year == yest.year && parsed.month == yest.month && parsed.day == yest.day) {
            dayTitle = "YESTERDAY'S SCREEN TIME";
          } else {
            dayTitle = DateFormat('EEE, d MMM yyyy').format(parsed).toUpperCase();
          }
        } catch (_) {
          dayTitle = "SCREEN TIME — $dStr";
        }
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isToday
                ? [const Color(0xFF7A3723), const Color(0xFFC44D28)]
                : [const Color(0xFF2C3E50), const Color(0xFF4A6572)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayTitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isToday ? 'Live Today' : 'Day Summary',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$hours', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                const Text('h ', style: TextStyle(color: Colors.white70, fontSize: 18)),
                Text('$minutes', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                const Text('m', style: TextStyle(color: Colors.white70, fontSize: 18)),
              ],
            ),
            if (night > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.nightlight_round, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Curfew phone usage: $night mins (11 PM - 5 AM)',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

  Widget _buildParentalControlHeroCard(BuildContext context) {
    return Obx(() {
      final isLocked = controller.isDeviceLocked.value;
      final limit = controller.dailyLimitMinutes.value;
      final start = controller.bedtimeStart.value;
      final end = controller.bedtimeEnd.value;
      final blockedCount = controller.blockedPackages.length;

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
                    color: isLocked
                        ? AppColors.cancelledRed.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_rounded : Icons.security_rounded,
                    color: isLocked ? AppColors.cancelledRed : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parental & App Controls', style: AppTextStyles.title),
                      Text(
                        isLocked
                            ? 'Student phone is remotely LOCKED'
                            : '$blockedCount restricted apps • Curfew $start - $end',
                        style: AppTextStyles.bodySm.copyWith(
                          color: isLocked ? AppColors.cancelledRed : AppColors.textSecondary,
                          fontWeight: isLocked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                  tooltip: 'Curfew & Limit Settings',
                  onPressed: () => _showCurfewSettingsSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLocked
                    ? AppColors.cancelledRed.withValues(alpha: 0.08)
                    : AppColors.mainBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLocked
                      ? AppColors.cancelledRed.withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isLocked ? Icons.screen_lock_portrait_rounded : Icons.lock_open_rounded,
                    color: isLocked ? AppColors.cancelledRed : AppColors.successGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remote Device Lock',
                          style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isLocked
                              ? 'Device is restricted from running student apps'
                              : 'Student can freely use permitted apps',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isLocked,
                    activeThumbColor: AppColors.cancelledRed,
                    activeTrackColor: AppColors.cancelledRed.withValues(alpha: 0.3),
                    onChanged: (val) => controller.toggleDeviceLock(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.nightlight_round, size: 16, color: Colors.orangeAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Curfew: $start - $end',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            limit > 0 ? 'Limit: $limit mins' : 'Limit: Unlimited',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAppBreakdownCard(BuildContext context) {
    return Obx(() {
      final list = controller.displayAppsList;
      final blockedCount = controller.blockedPackages.length;
      final currentFilter = controller.selectedAppFilter.value;
      final isToday = controller.isTodaySelected;
      final dayNote = isToday ? 'today' : 'on ${controller.effectiveSelectedDate}';

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Usage & Restrictions', style: AppTextStyles.title),
                      const SizedBox(height: 2),
                      Text(
                        'Apps used $dayNote • Block or permit apps on student device',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showRestrictAppSheet(context),
                  icon: const Icon(Icons.add_moderator_rounded, size: 16),
                  label: const Text('Restrict App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cancelledRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar for apps
            TextField(
              controller: controller.appSearchController,
              onChanged: (val) => controller.appSearchQuery.value = val,
              decoration: InputDecoration(
                hintText: 'Search apps (e.g. YouTube, Instagram)...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: controller.appSearchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          controller.appSearchController.clear();
                          controller.appSearchQuery.value = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAppFilterChip('All', list.length),
                  const SizedBox(width: 8),
                  _buildAppFilterChip(
                    controller.isTodaySelected ? 'Used Today' : 'Used on Day',
                    controller.currentDayRawApps.length,
                  ),
                  const SizedBox(width: 8),
                  _buildAppFilterChip('Restricted', blockedCount, isDestructive: true),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (list.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.apps_rounded, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        currentFilter == 'Restricted'
                            ? 'No apps restricted yet for this student.'
                            : 'No apps recorded for this day.',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final item = list[index];
                  final pkg = (item['packageName'] ?? '').toString();
                  final name = (item['appName'] ?? pkg).toString();
                  final mins = (item['minutes'] as int?) ?? 0;
                  final isBlocked = item['isBlocked'] == true;
                  final total = controller.selectedDayTotalMinutes > 0
                      ? controller.selectedDayTotalMinutes
                      : 1;
                  final progress = (mins / total).clamp(0.0, 1.0);
                  final pct = (progress * 100).round();

                  return Row(
                    children: [
                      // App Icon with Block / Allow badge
                      AppBrandIcon(
                        packageName: pkg,
                        appName: name,
                        size: 42,
                        isBlocked: isBlocked,
                      ),
                      const SizedBox(width: 12),

                      // Name, Package, & Usage
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: AppTextStyles.bodyMd.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isBlocked ? AppColors.cancelledRed : null,
                                      decoration: isBlocked ? TextDecoration.lineThrough : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isBlocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.cancelledRed.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BLOCKED',
                                      style: TextStyle(
                                        color: AppColors.cancelledRed,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pkg,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (mins > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isBlocked ? AppColors.cancelledRed : AppColors.primary,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      minHeight: 4,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$mins mins ($pct%)',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Allow / Block Switch
                      Column(
                        children: [
                          Switch(
                            value: !isBlocked,
                            activeThumbColor: AppColors.successGreen,
                            inactiveThumbColor: AppColors.cancelledRed,
                            inactiveTrackColor: AppColors.cancelledRed.withValues(alpha: 0.25),
                            onChanged: (allowed) {
                              controller.toggleAppBlock(pkg, name, !allowed);
                            },
                          ),
                          Text(
                            isBlocked ? 'Blocked' : 'Allowed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isBlocked ? AppColors.cancelledRed : AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      );
    });
  }

  Widget _buildAppFilterChip(String label, int count, {bool isDestructive = false}) {
    return Obx(() {
      final isSelected = controller.selectedAppFilter.value == label;
      final Color activeColor = isDestructive ? AppColors.cancelledRed : AppColors.primary;

      return GestureDetector(
        onTap: () => controller.selectedAppFilter.value = label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : activeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : activeColor.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : activeColor,
            ),
          ),
        ),
      );
    });
  }

  void _showRestrictAppSheet(BuildContext context) {
    final customPkgController = TextEditingController();
    final customNameController = TextEditingController();

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Restrict Distracting Apps', style: AppTextStyles.title),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              Text(
                'Select common apps or enter a custom package to restrict on this student\'s device.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Quick Presets'),
              const SizedBox(height: 8),
              Obx(() {
                final blocked = controller.blockedPackages;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StudentScreenTimeController.presetDistractingApps.map((preset) {
                    final name = preset['name']!;
                    final pkg = preset['pkg']!;
                    final isRestricted = blocked.contains(pkg);

                    return FilterChip(
                      selected: isRestricted,
                      showCheckmark: false,
                      avatar: AppBrandIcon(
                        packageName: pkg,
                        appName: name,
                        size: 20,
                        showBadge: false,
                      ),
                      label: Text(
                        isRestricted ? '$name (Blocked)' : name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isRestricted ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selectedColor: AppColors.cancelledRed,
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (val) {
                        controller.toggleAppBlock(pkg, name, val);
                      },
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Add Custom Package'),
              const SizedBox(height: 8),
              TextField(
                controller: customNameController,
                decoration: InputDecoration(
                  labelText: 'App Name (e.g. Free Fire, BGMI)',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: customPkgController,
                decoration: InputDecoration(
                  labelText: 'Package Name (e.g. com.dts.freefireth)',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final pkg = customPkgController.text.trim();
                    final name = customNameController.text.trim();
                    if (pkg.isNotEmpty) {
                      controller.addCustomBlockedApp(pkg, name);
                      Get.back();
                    } else {
                      AppSnackbar.warning('Missing Package', 'Please enter a package name to block.');
                    }
                  },
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Add Restriction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cancelledRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showCurfewSettingsSheet(BuildContext context) {
    final limitController = TextEditingController(
      text: controller.dailyLimitMinutes.value > 0
          ? controller.dailyLimitMinutes.value.toString()
          : '',
    );
    final bedtimeStartRx = controller.bedtimeStart.value.obs;
    final bedtimeEndRx = controller.bedtimeEnd.value.obs;

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Curfew & Limits', style: AppTextStyles.title),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Daily Screen Limit (in Minutes, e.g. 120)',
                  hintText: 'Leave empty for no limit',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Curfew Start', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: const TimeOfDay(hour: 23, minute: 0),
                                );
                                if (time != null) {
                                  final h = time.hour.toString().padLeft(2, '0');
                                  final m = time.minute.toString().padLeft(2, '0');
                                  bedtimeStartRx.value = '$h:$m';
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(bedtimeStartRx.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Curfew End', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: const TimeOfDay(hour: 5, minute: 0),
                                );
                                if (time != null) {
                                  final h = time.hour.toString().padLeft(2, '0');
                                  final m = time.minute.toString().padLeft(2, '0');
                                  bedtimeEndRx.value = '$h:$m';
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(bedtimeEndRx.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final mins = int.tryParse(limitController.text.trim()) ?? 0;
                    controller.updateCurfewAndLimit(
                      limitMinutes: mins,
                      startBedtime: bedtimeStartRx.value,
                      endBedtime: bedtimeEndRx.value,
                    );
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Policy'),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildHistoryCard() {
    return Obx(() {
      final records = controller.historyRecords;
      if (records.isEmpty) {
        return AppCard(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Recent Activity Logs'),
              const SizedBox(height: 8),
              Text(
                'No past screen time activity recorded yet.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }

      final dateFmt = DateFormat('EEE, d MMM yyyy');

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Recent Activity Logs'),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final rec = records[index];
                final rawDate = (rec['date'] ?? '').toString();
                final dayIso = rawDate.split('T').first;
                String formattedDate = dayIso;
                try {
                  final parsed = DateTime.parse(dayIso);
                  formattedDate = dateFmt.format(parsed);
                } catch (_) {}

                final mins = StudentScreenTimeController.toInt(
                  rec['total_screen_time_minutes'] ??
                      rec['totalScreenTimeMinutes'] ??
                      rec['totalMinutes'] ??
                      rec['minutes'],
                );
                final night = StudentScreenTimeController.toInt(
                  rec['night_screen_time_minutes'] ??
                      rec['nightScreenTimeMinutes'] ??
                      rec['nightMinutes'] ??
                      rec['night'],
                );
                final h = mins ~/ 60;
                final m = mins % 60;
                final isSelected = controller.effectiveSelectedDate == dayIso;

                return InkWell(
                  onTap: () {
                    controller.selectDate(dayIso);
                    AppSnackbar.info(
                      'Day Selected',
                      'Displaying screen time and app usage for $formattedDate.',
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    formattedDate,
                                    style: AppTextStyles.bodyMd.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Viewing',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (night > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '🌙 ${night}m night curfew',
                                    style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w500),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${h}h ${m}m',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: isSelected ? AppColors.primary : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
