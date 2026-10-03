import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
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
        _SummaryStrip(),
        const SizedBox(height: AppDimens.gapMd),
        _SearchField(),
        const SizedBox(height: AppDimens.gapSm),
        _FilterChips(),
        const SizedBox(height: AppDimens.gapMd),
        Obx(() {
          if (controller.isLoadingStudents.value && controller.allStudents.isEmpty) {
            return const SkeletonList(count: 6, itemHeight: 76);
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
