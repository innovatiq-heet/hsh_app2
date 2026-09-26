import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/user_role.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/section_header.dart';
import 'student_screen_time_controller.dart';

class StudentScreenTimeScreen extends GetView<StudentScreenTimeController> {
  const StudentScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Obx(() {
        final isLeader = controller.currentRole.value.canViewScreenTime;
        final selected = controller.selectedStudent.value;

        // Dynamic header title and subtitle based on view state
        final String headerTitle;
        final String headerSubtitle;

        if (selected != null) {
          headerTitle = selected['name'] ?? 'Student Screen Time';
          headerSubtitle =
              'Room ${selected['room'] ?? 'N/A'} • ID: ${selected['aadhar'] ?? ''} • Device Managed';
        } else if (isLeader) {
          headerTitle = 'Parental & Screen Time Control';
          headerSubtitle = 'Live resident device monitoring & digital curfew management';
        } else {
          headerTitle = 'Digital Wellbeing & Curfew';
          headerSubtitle = 'Personal screen usage, daily limits & hostel policies';
        }

        return CustomScrollView(
          slivers: [
            SliverGradientHeader(
              title: headerTitle,
              subtitle: headerSubtitle,
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: selected != null ? 'Back to directory' : 'Back',
                onPressed: selected != null
                    ? controller.clearSelectedStudent
                    : () => Get.back(),
              ),
              actions: [
                if (isLeader && selected != null)
                  HeaderIconButton(
                    icon: Icons.shield_outlined,
                    tooltip: 'Parental Policies & Curfew Schedule',
                    onPressed: () => _showPolicySettingsDialog(context),
                  ),
                HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onPressed: () {
                    if (isLeader && selected == null) {
                      controller.fetchStudentsList();
                    } else {
                      controller.fetchLiveStatus();
                      controller.fetchHistory();
                      if (selected != null) {
                        controller.fetchStudentPolicies(selected);
                      }
                    }
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                child: isLeader && selected == null
                    ? _buildStudentsDirectoryView()
                    : _buildDetailedScreenTimeView(isLeader, selected),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Directory view for Leader: list of all students with live status, screen time & filter chips
  Widget _buildStudentsDirectoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              TextField(
                controller: controller.searchFilterController,
                onChanged: controller.filterStudents,
                decoration: InputDecoration(
                  hintText: 'Search student name, room (e.g. A-204), or ID...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: controller.searchFilterController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            controller.searchFilterController.clear();
                            controller.filterStudents('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.mainBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter Chips: All, Online Now 🟢, Over Limit ⚠️, Curfew Alerts 🌙, Locked 🔒
              Obx(() {
                final currentFilter = controller.selectedFilter.value;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: StudentScreenTimeController.filterChips.map((chip) {
                      final isSelected = currentFilter == chip;

                      // Display badge count per chip
                      String badgeText = '';
                      if (chip == 'All') {
                        badgeText = ' (${controller.allStudents.length})';
                      } else if (chip.startsWith('Online Now')) {
                        badgeText = ' (${controller.countOnline})';
                      } else if (chip.startsWith('Over Limit')) {
                        badgeText = ' (${controller.countOverLimit})';
                      } else if (chip.startsWith('Curfew Alerts')) {
                        badgeText = ' (${controller.countCurfewAlerts})';
                      } else if (chip.startsWith('Locked')) {
                        badgeText = ' (${controller.countLocked})';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(
                            '$chip$badgeText',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          onSelected: (_) => controller.setFilter(chip),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapMd),

        Obx(() {
          if (controller.isLoadingStudents.value) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final students = controller.filteredStudents;
          if (students.isEmpty) {
            return AppCard(
              padding: const EdgeInsets.all(AppDimens.cardPadding * 2),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_search_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No students found', style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text(
                      'Try changing your search keywords or filter chip',
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
            itemCount: students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final student = students[index];
              final totalMins = student['totalScreenTimeMinutes'] as int? ?? 0;
              final nightMins = student['nightScreenTimeMinutes'] as int? ?? 0;
              final isOnline = student['isOnline'] as bool? ?? false;
              final isLocked = student['isLocked'] as bool? ?? false;
              final limit = (student['dailyLimitMinutes'] as int? ?? 0) > 0
                  ? (student['dailyLimitMinutes'] as int)
                  : 180;
              final isOverLimit = totalMins >= limit;

              final hours = totalMins ~/ 60;
              final minutes = totalMins % 60;

              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: InkWell(
                  onTap: () => controller.selectStudent(student),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? Colors.green : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    student['name'] ?? 'Unknown',
                                    style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isLocked) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_rounded, size: 10, color: Colors.red),
                                        const SizedBox(width: 3),
                                        Text(
                                          'LOCKED',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Room ${student['room'] ?? 'N/A'} • ID: ${student['aadhar'] ?? ''} • Device Managed',
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${hours}h ${minutes}m',
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isOverLimit ? Colors.red : AppColors.primary,
                            ),
                          ),
                          if (nightMins > 0)
                            Text(
                              '🌙 ${nightMins}m curfew alert',
                              style: AppTextStyles.bodySm.copyWith(
                                color: Colors.orange.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  /// Detailed view for a single student (Leader view) OR self digital wellbeing (Student view)
  Widget _buildDetailedScreenTimeView(bool isLeader, dynamic selectedStudent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  onPressed: controller.clearSelectedStudent,
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
                        'Room ${selectedStudent['room'] ?? 'N/A'} • ID: ${selectedStudent['aadhar'] ?? ''} • Device Managed',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showPolicySettingsDialog(Get.context!),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Policies'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Android Usage Permission Warning for Student Device
        Obx(() {
          if (!controller.hasUsagePermission.value && !isLeader) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Usage Access Required',
                            style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Grant usage access to track screen time & app restrictions accurately.',
                          style: AppTextStyles.bodySm.copyWith(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: controller.requestUsagePermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text('Grant'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        // Android Overlay Permission Warning for Student Device
        Obx(() {
          if (!controller.hasOverlayPermission.value && !isLeader) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined, color: Colors.blue.shade900, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Display Over Other Apps Permission',
                            style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Required for bedtime curfew alerts and device lock enforcement.',
                          style: AppTextStyles.bodySm.copyWith(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: controller.requestOverlayPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text('Enable'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        // Remote Lock Status Banner
        Obx(() {
          if (controller.isDeviceLocked.value) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hostel Device Lock Active',
                          style: AppTextStyles.bodyMd
                              .copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Access restricted per hostel guidelines. Contact your warden or administrator to restore normal access.',
                          style: AppTextStyles.bodySm.copyWith(color: Colors.red.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        // Live Status Card
        _buildLiveCard(),
        const SizedBox(height: AppDimens.gapMd),

        // Daily Screen Time Allowance Card
        _buildTodayUsageCard(),
        const SizedBox(height: AppDimens.gapMd),

        // Night Curfew Schedule Card
        _buildCurfewScheduleCard(),
        const SizedBox(height: AppDimens.gapMd),

        // App Activity & Parental Rules Card
        _buildAppBreakdownCard(isLeader),
        const SizedBox(height: AppDimens.gapMd),

        // Historical Daily Logs from API
        _buildHistoryCard(),
      ],
    );
  }

  Widget _buildLiveCard() {
    return Obx(() {
      final online = controller.isOnline.value;
      final screenOn = controller.isScreenOn.value;
      final app = controller.currentApp.value;

      final String statusTitle;
      if (online) {
        statusTitle = screenOn ? 'Screen Active (In Use)' : 'Device in Standby (Screen Off)';
      } else {
        statusTitle = 'Device Offline / Not Connected';
      }

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
                    statusTitle,
                    style: AppTextStyles.title,
                  ),
                  if (app.isNotEmpty && app != 'Idle')
                    Text(
                      'Active: $app',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
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
              child: const Text('Live Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTodayUsageCard() {
    return Obx(() {
      final total = controller.totalMinutesToday.value;
      final hours = total ~/ 60;
      final minutes = total % 60;
      final night = controller.nightMinutesToday.value;
      final limit = controller.dailyLimitMinutes.value;
      final isOverLimit = limit > 0 && total >= limit;
      final progress = limit > 0 ? (total / limit).clamp(0.0, 1.0) : 0.0;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7A3723), Color(0xFFC44D28)],
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
                const Text(
                  'Daily Screen Time Allowance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (limit > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverLimit ? Colors.red.shade700 : Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOverLimit
                          ? 'Allowance Exceeded (${limit ~/ 60}h ${limit % 60}m)'
                          : 'Allowance: ${limit ~/ 60}h ${limit % 60}m',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$hours', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                const Text('h ', style: TextStyle(color: Colors.white70, fontSize: 18)),
                Text('$minutes', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                const Text('m', style: TextStyle(color: Colors.white70, fontSize: 18)),
              ],
            ),
            if (limit > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverLimit ? Colors.amberAccent : Colors.white,
                ),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ],
            if (night > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.nightlight_round, color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '🌙 Late-Night Usage: ${night}m recorded during curfew (11:00 PM – 5:00 AM)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Flags phone activity during sleeping hours to promote healthy rest habits.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
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

  /// Informational card displaying active bedtime curfew hours
  Widget _buildCurfewScheduleCard() {
    return Obx(() {
      final start = controller.bedtimeStart.value.isNotEmpty ? controller.bedtimeStart.value : '23:00';
      final end = controller.bedtimeEnd.value.isNotEmpty ? controller.bedtimeEnd.value : '05:00';

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bedtime_outlined, color: Colors.indigo, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Night Curfew / Bedtime Hours',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Curfew: ${_formatTimeStr(start)} to ${_formatTimeStr(end)}',
                    style: TextStyle(fontSize: 12, color: Colors.indigo.shade800, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Flags phone activity during sleeping hours to promote healthy rest habits.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// App Activity & Parental Rules with Tabs: Used Today | All Installed Apps | Restricted Apps
  Widget _buildAppBreakdownCard(bool isLeader) {
    return Obx(() {
      final currentTab = controller.selectedAppTab.value;
      final apps = controller.getFilteredAppsList();
      final total = controller.totalMinutesToday.value > 0 ? controller.totalMinutesToday.value : 1;

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(title: 'App Activity & Parental Rules'),
                if (isLeader)
                  Text(
                    'Leader Controls Active',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: StudentScreenTimeController.appTabs.map((tab) {
                  final isSelected = currentTab == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      backgroundColor: AppColors.mainBackground,
                      selectedColor: AppColors.primary,
                      onSelected: (_) => controller.setAppTab(tab),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // App Search Input
            TextField(
              controller: controller.appSearchController,
              onChanged: controller.filterApps,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: controller.appSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          controller.appSearchController.clear();
                          controller.filterApps('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.mainBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (apps.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.apps_rounded, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        currentTab == 'Used Today'
                            ? 'No apps recorded for today yet.'
                            : (currentTab == 'Restricted Apps'
                                ? 'No apps are currently restricted.'
                                : 'No installed apps in catalog yet.'),
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: apps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final mins = (app['minutes'] as int?) ?? 0;
                  final name = (app['appName'] ?? app['packageName'] ?? 'App').toString();
                  final pkg = (app['packageName'] ?? '').toString();
                  final isBlocked = app['isBlocked'] == true;
                  final progress = (mins / total).clamp(0.0, 1.0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (pkg.isNotEmpty)
                                        Text(
                                          pkg,
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (isBlocked) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'RESTRICTED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (mins > 0)
                            Text('$mins mins', style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary))
                          else
                            Text('Not opened today',
                                style: AppTextStyles.bodySm.copyWith(color: Colors.grey.shade400, fontSize: 11)),
                          if (isLeader && pkg.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Switch(
                              value: !isBlocked,
                              activeTrackColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                              inactiveTrackColor: Colors.red.shade100,
                              onChanged: (allowed) {
                                controller.toggleAppBlock(pkg, name, !allowed);
                              },
                            ),
                          ],
                        ],
                      ),
                      if (mins > 0) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isBlocked ? Colors.red : AppColors.primary,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 5,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      );
    });
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
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final rec = records[index];
                final total = (rec['total_screen_time_minutes'] ?? rec['totalScreenTimeMinutes'] as int?) ?? 0;
                final night = (rec['night_screen_time_minutes'] ?? rec['nightScreenTimeMinutes'] as int?) ?? 0;
                final hours = total ~/ 60;
                final minutes = total % 60;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (rec['date'] ?? '').toString().split('T').first,
                              style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (night > 0)
                              Text(
                                '🌙 Curfew phone use: ${night}m',
                                style: AppTextStyles.bodySm.copyWith(color: Colors.orange.shade800),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${hours}h ${minutes}m',
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.bold,
                          color: total > 360 ? Colors.red : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }

  /// Policy Settings Sheet for Leaders / Wardens
  void _showPolicySettingsDialog(BuildContext context) {
    final limitController = TextEditingController(
      text: controller.dailyLimitMinutes.value > 0 ? '${controller.dailyLimitMinutes.value}' : '',
    );
    final isLockedRx = controller.isDeviceLocked.value.obs;
    final bedtimeStartRx = (controller.bedtimeStart.value.isNotEmpty ? controller.bedtimeStart.value : '23:00').obs;
    final bedtimeEndRx = (controller.bedtimeEnd.value.isNotEmpty ? controller.bedtimeEnd.value : '05:00').obs;

    // Presets: No Limit (0), 1.5 hrs (90), 2 hrs (120), 3 hrs (180), 4 hrs (240)
    final presets = [
      {'label': 'No Limit', 'mins': 0},
      {'label': '1.5 hrs', 'mins': 90},
      {'label': '2 hrs', 'mins': 120},
      {'label': '3 hrs', 'mins': 180},
      {'label': '4 hrs', 'mins': 240},
    ];

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text('Parental Policies & Curfew Schedule', style: AppTextStyles.title),
                ],
              ),
              const Divider(height: 24),

              // 1. Daily Screen Allowance
              const Text('Daily Screen Allowance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),

              // Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: presets.map((p) {
                    final mins = p['mins'] as int;
                    final label = p['label'] as String;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.mainBackground,
                        onPressed: () {
                          limitController.text = mins > 0 ? '$mins' : '';
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Custom: e.g. 180 mins (3 hrs)',
                  hintText: 'Enter minutes (0 for unlimited)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),

              // 2. Night Curfew / Bedtime Hours
              const Text('Night Curfew / Bedtime Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                'Flags phone activity during sleeping hours to promote healthy rest habits.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Obx(() => InkWell(
                          onTap: () async {
                            final parsed = _parseTimeOfDay(bedtimeStartRx.value);
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: parsed,
                            );
                            if (picked != null) {
                              bedtimeStartRx.value = _formatTimeOfDay(picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.mainBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Curfew Start', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.bedtime_outlined, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimeStr(bedtimeStartRx.value),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 18),
                  ),
                  Expanded(
                    child: Obx(() => InkWell(
                          onTap: () async {
                            final parsed = _parseTimeOfDay(bedtimeEndRx.value);
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: parsed,
                            );
                            if (picked != null) {
                              bedtimeEndRx.value = _formatTimeOfDay(picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.mainBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Curfew End', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimeStr(bedtimeEndRx.value),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Emergency Device Lock
              Obx(() => Container(
                    decoration: BoxDecoration(
                      color: isLockedRx.value ? Colors.red.shade50 : AppColors.mainBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SwitchListTile(
                      title: const Text('Emergency Device Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Instantly restricts device to emergency calls and hostel portal'),
                      value: isLockedRx.value,
                      activeTrackColor: Colors.red,
                      onChanged: (val) => isLockedRx.value = val,
                    ),
                  )),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final mins = int.tryParse(limitController.text.trim()) ?? 0;
                    controller.updatePolicy(
                      limitMinutes: mins,
                      startBedtime: bedtimeStartRx.value,
                      endBedtime: bedtimeEndRx.value,
                      lockDevice: isLockedRx.value,
                    );
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Policy Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 23, minute: 0);
    }
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatTimeStr(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2026, 1, 1, hour, minute);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mStr = dt.minute.toString().padLeft(2, '0');
      return '$h12:$mStr $period';
    } catch (_) {
      return timeStr;
    }
  }
}
