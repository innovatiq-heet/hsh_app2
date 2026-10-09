import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/geofence/geofence_policy_model.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/student_screen_time_controller.dart';
import 'app_brand_icon.dart';

/// Warden's directory: search, quick filters and one row per student that
/// answers "is this phone online, is it compliant, how much was it used?"
class StudentDirectoryView extends GetView<StudentScreenTimeController> {
  const StudentDirectoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GlobalCurfewBanner(),
        const SizedBox(height: AppDimens.gapMd),
        _SummaryStrip(),
        const SizedBox(height: AppDimens.gapMd),
        _SearchField(),
        const SizedBox(height: AppDimens.gapSm),
        _FilterChips(),
        const SizedBox(height: AppDimens.gapMd),
        Obx(() {
          if (controller.isLoadingStudents.value && controller.allStudents.isEmpty) {
            return const SkeletonList(
              count: 6,
              itemHeight: 76,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
            );
          }
          final list = controller.filteredStudents;
          if (list.isEmpty) {
            final filtered = controller.directoryFilter.value != 'All' ||
                controller.searchText.value.isNotEmpty;
            return AppCard(
              child: EmptyState(
                icon: filtered ? Icons.filter_alt_off_rounded : Icons.phonelink_off_rounded,
                title: filtered ? 'No students match' : 'No devices reporting yet',
                message: filtered
                    ? 'Try another filter or clear the search.'
                    : 'Students appear here once their phone completes setup and sends its first report.',
                actionLabel: filtered ? 'Clear filters' : null,
                onAction: filtered
                    ? () {
                        controller.searchFilterController.clear();
                        controller.setDirectoryFilter('All');
                      }
                    : null,
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapSm),
            itemBuilder: (_, i) => _StudentRow(student: list[i]),
          );
        }),
      ],
    );
  }
}

/// Four at-a-glance numbers across the whole hostel.
class _SummaryStrip extends GetView<StudentScreenTimeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final all = controller.allStudents;
      final online = controller.directoryCount('Online');
      final locked = controller.directoryCount('Locked');
      final attention = all.where(StudentScreenTimeController.isStudentTampered).length;
      final totalMins = all.fold<int>(
        0, (sum, s) => sum + StudentScreenTimeController.toInt(s['totalScreenTimeMinutes']));
      final avg = all.isEmpty ? 0 : totalMins ~/ all.length;

      Widget tile(String value, String label, Color color, {VoidCallback? onTap}) => Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Column(
                  children: [
                    Text(value, style: AppTextStyles.headline.copyWith(color: color, fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          );

      return Row(
        children: [
          tile('$online/${all.length}', 'Online', AppColors.successGreen,
              onTap: () => controller.setDirectoryFilter('Online')),
          const SizedBox(width: AppDimens.gapSm),
          tile(StudentScreenTimeController.formatMinutes(avg), 'Avg today', AppColors.primary),
          const SizedBox(width: AppDimens.gapSm),
          tile('$locked', 'Locked', AppColors.cancelledRed,
              onTap: () => controller.setDirectoryFilter('Locked')),
          const SizedBox(width: AppDimens.gapSm),
          tile('$attention', 'Attention', AppColors.warningOrange,
              onTap: () => controller.setDirectoryFilter('Attention')),
        ],
      );
    });
  }
}

class _SearchField extends GetView<StudentScreenTimeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() => TextField(
          controller: controller.searchFilterController,
          onChanged: controller.filterStudents,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search name, room or Aadhar',
            hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
            suffixIcon: controller.searchText.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      controller.searchFilterController.clear();
                      controller.filterStudents('');
                    },
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
        ));
  }
}

class _FilterChips extends GetView<StudentScreenTimeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.directoryFilter.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in StudentScreenTimeController.directoryFilters) ...[
              _Chip(
                label: f,
                count: controller.directoryCount(f),
                selected: selected == f,
                color: switch (f) {
                  'Locked' => AppColors.cancelledRed,
                  'Attention' => AppColors.warningOrange,
                  'Online' => AppColors.successGreen,
                  _ => AppColors.primary,
                },
                onTap: () => controller.setDirectoryFilter(f),
              ),
              const SizedBox(width: AppDimens.gapSm),
            ],
          ],
        ),
      );
    });
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.caption.copyWith(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends GetView<StudentScreenTimeController> {
  final dynamic student;
  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final name = (student['name'] ?? 'Student').toString();
    final room = (student['room'] ?? 'N/A').toString();
    final isOnline = student['isOnline'] == true;
    final isScreenOn = student['isScreenOn'] == true;
    final totalMins = StudentScreenTimeController.toInt(student['totalScreenTimeMinutes']);
    final nightMins = StudentScreenTimeController.toInt(student['nightScreenTimeMinutes']);
    final locked = StudentScreenTimeController.isStudentLocked(student);
    final restricted = StudentScreenTimeController.blockedOf(student).length;
    final tampered = StudentScreenTimeController.isStudentTampered(student);
    final lastSeen = StudentScreenTimeController.lastSeenOf(student);
    final currentApp = (student['currentApp'] ?? '').toString();
    final currentPkg = (student['currentPackage'] ?? '').toString();

    final statusColor = isOnline
        ? (isScreenOn ? AppColors.successGreen : AppColors.warningOrange)
        : AppColors.textLight;
    final statusText = isOnline
        ? (isScreenOn
            ? (currentApp.isNotEmpty && currentApp != 'Idle' ? 'Using $currentApp' : 'Screen on')
            : 'Standby')
        : (lastSeen != null ? 'Seen ${StudentScreenTimeController.relativeTime(lastSeen)}' : 'Offline');

    final initials = name.trim().isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase()
        : 'S';

    return AppCard(
      onTap: () => controller.selectStudent(student),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar + presence dot (or the app they're in right now)
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: tampered
                    ? AppColors.warningOrange.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: AppTextStyles.title.copyWith(
                    color: tampered ? AppColors.warningOrange : AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                bottom: -3,
                right: -3,
                child: isScreenOn && currentPkg.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: AppBrandIcon(packageName: currentPkg, appName: currentApp, size: 18, showBadge: false),
                      )
                    : Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
              ),
            ],
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
                        name,
                        style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(room, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: AppTextStyles.bodySm.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (locked || restricted > 0 || tampered) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (tampered)
                        const _Tag(icon: Icons.gpp_bad_rounded, label: 'Monitoring off', color: AppColors.warningOrange),
                      if (locked)
                        const _Tag(icon: Icons.lock_rounded, label: 'Locked', color: AppColors.cancelledRed),
                      if (restricted > 0 && !locked)
                        _Tag(icon: Icons.block_rounded, label: '$restricted blocked', color: AppColors.secondary),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                StudentScreenTimeController.formatMinutes(totalMins),
                style: AppTextStyles.title.copyWith(color: AppColors.primary),
              ),
              if (nightMins > 0) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.nightlight_round, size: 11, color: AppColors.cancelledRed),
                    const SizedBox(width: 2),
                    Text(
                      '${nightMins}m night',
                      style: AppTextStyles.caption.copyWith(color: AppColors.cancelledRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Hostel-wide Curfew status & quick 1-tap global control banner for wardens.
class _GlobalCurfewBanner extends GetView<StudentScreenTimeController> {
  const _GlobalCurfewBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final policy = controller.globalCurfewPolicy.value;
      final isActive = policy.isActive;
      final isUpdating = controller.isUpdatingCurfew.value;
      final accentColor = isActive ? AppColors.successGreen : AppColors.warningOrange;

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? Icons.nightlight_round : Icons.bedtime_off_outlined,
                color: accentColor,
                size: 22,
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
                          'Night Curfew',
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: isActive ? 'ACTIVE' : 'TURNED OFF',
                        color: accentColor,
                        icon: isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        policy.formatTimeRange(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _showEditCurfewHours(context, controller, policy),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Edit Hours',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CurfewToggleButton(
              isActive: isActive,
              isUpdating: isUpdating,
              onPressed: isUpdating ? null : () => controller.toggleGlobalCurfew(!isActive),
            ),
          ],
        ),
      );
    });
  }

  void _showEditCurfewHours(
    BuildContext context,
    StudentScreenTimeController controller,
    GeofencePolicyModel policy,
  ) {
    TimeOfDay start = policy.startTime;
    TimeOfDay end = policy.endTime;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setState) {
          String formatTime(TimeOfDay t) {
            final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
            final min = t.minute.toString().padLeft(2, '0');
            final period = t.period == DayPeriod.am ? 'AM' : 'PM';
            return '$hour:$min $period';
          }

          return Container(
            padding: const EdgeInsets.all(AppDimens.cardPadding),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Set Global Curfew Hours',
                        style: AppTextStyles.headline.copyWith(fontSize: 18),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Get.back(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Applies to all hostel students. Phones evaluate curfew boundaries during this window.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppDimens.gapLg),
                  Row(
                    children: [
                      Expanded(
                        child: _CurfewTimeTile(
                          label: 'START TIME',
                          timeStr: formatTime(start),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: start,
                            );
                            if (picked != null) {
                              setState(() => start = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: _CurfewTimeTile(
                          label: 'END TIME',
                          timeStr: formatTime(end),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: end,
                            );
                            if (picked != null) {
                              setState(() => end = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapXl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Get.back();
                            controller.updateGlobalCurfewTimes(start, end);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                          ),
                          child: const Text('Save Hours', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }
}

class _CurfewTimeTile extends StatelessWidget {
  final String label;
  final String timeStr;
  final VoidCallback onTap;

  const _CurfewTimeTile({
    required this.label,
    required this.timeStr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 10)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurfewToggleButton extends StatelessWidget {
  final bool isActive;
  final bool isUpdating;
  final VoidCallback? onPressed;

  const _CurfewToggleButton({
    required this.isActive,
    required this.isUpdating,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      // Button to turn OFF curfew
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUpdating)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cancelledRed),
                  )
                else
                  const Icon(Icons.power_settings_new_rounded, size: 15, color: AppColors.cancelledRed),
                const SizedBox(width: 6),
                Text(
                  'Turn OFF',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.cancelledRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Button to turn ON curfew
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUpdating)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  const Icon(Icons.power_settings_new_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Turn ON',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
