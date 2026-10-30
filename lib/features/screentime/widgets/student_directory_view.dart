import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/models/geofence/geofence_policy_model.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/student_screen_time_controller.dart';
import 'app_brand_icon.dart';
import 'app_requests_banner.dart';

/// Warden's directory: search, quick filters and one row per student that
/// answers "is this phone online, is it compliant, how much was it used?"
///
/// This is a sliver: the rows are built lazily by a [SliverList] inside the
/// screen's own scroll view, so only the rows on screen exist however many
/// students are loaded.
class StudentDirectoryView extends GetView<StudentScreenTimeController> {
  const StudentDirectoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GlobalCurfewBanner(),
              const SizedBox(height: AppDimens.gapMd),
              const AppRequestsBanner(),
              _SummaryStrip(),
              const SizedBox(height: AppDimens.gapMd),
              _SearchField(),
              const SizedBox(height: AppDimens.gapMd),
            ],
          ),
        ),
        Obx(_buildList),
      ],
    );
  }

  Widget _buildList() {
    if (controller.isLoadingStudents.value && controller.allStudents.isEmpty) {
      return const SliverToBoxAdapter(
        child: SkeletonList(
          count: 6,
          itemHeight: 76,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
        ),
      );
    }
    final list = controller.filteredStudents;
    if (list.isEmpty) {
      if (controller.isSearchingServer.value) {
        return const SliverToBoxAdapter(
          child: SkeletonList(
            count: 3,
            itemHeight: 76,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
          ),
        );
      }
      final filtered =
          controller.directoryFilter.value != 'All' ||
          controller.searchText.value.isNotEmpty;
      return SliverToBoxAdapter(
        child: AppCard(
          child: EmptyState(
            icon: filtered
                ? Icons.filter_alt_off_rounded
                : Icons.phonelink_off_rounded,
            title: filtered ? 'No students match' : 'No devices reporting yet',
            message: filtered
                ? 'Try another filter or clear the search.'
                : 'Students appear here once their phone completes setup and sends its first report.',
            actionLabel: filtered ? 'Clear filters' : null,
            onAction: filtered
                ? () {
                    controller.clearSearch();
                    controller.setDirectoryFilter('All');
                  }
                : null,
          ),
        ),
      );
    }

    final shown = controller.visibleStudentCount.value.clamp(0, list.length);
    final hasMoreToShow =
        shown < list.length || controller.hasMoreStudents.value;

    return SliverMainAxisGroup(
      slivers: [
        SliverList.separated(
          itemCount: shown,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapSm),
          findItemIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final i = list.indexWhere((s) => _rowKey(s) == key.value);
            return i < 0 || i >= shown ? null : i;
          },
          itemBuilder: (_, i) =>
              _StudentRow(key: ValueKey(_rowKey(list[i])), student: list[i]),
        ),
        if (hasMoreToShow)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: controller.isLoadingMore.value
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: controller.loadMoreItems,
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        label: Text(
                          shown < list.length
                              ? 'Show more ($shown of ${list.length})'
                              : 'Load more from server',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          backgroundColor: const Color(
                            0xFFE0F2FE,
                          ).withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  /// Stable per-student key so rows keep their state when the list reorders.
  static String _rowKey(dynamic s) {
    if (s is! Map) return '$s';
    final id = s['id']?.toString().trim() ?? '';
    return id.isNotEmpty
        ? 'id:$id'
        : 'n:${s['name']}:${s['room'] ?? s['room_number']}';
  }
}

/// Four at-a-glance numbers across the whole hostel.
class _SummaryStrip extends GetView<StudentScreenTimeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.directoryFilter.value;
      final total = controller.directoryCount('All');
      final online = controller.directoryCount('Online');
      final offline = controller.directoryCount('Offline');
      final locked = controller.directoryCount('Locked');
      final attention = controller.directoryCount('Attention');

      Widget tile(
        String filter,
        String value,
        String label,
        Color color,
        Color bg,
        Color border, {
        VoidCallback? onTap,
      }) {
        final selected = active == filter;
        return Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? color : bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? color : border),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: selected ? Colors.white : color,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF64748B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Row(
        children: [
          tile(
            'All',
            '$total',
            'Total',
            const Color(0xFF0284C7),
            const Color(0xFFF0F9FF),
            const Color(0xFFBAE6FD),
            onTap: () => controller.setDirectoryFilter('All'),
          ),
          const SizedBox(width: 6),
          tile(
            'Online',
            '$online',
            'Online',
            const Color(0xFF16A34A),
            const Color(0xFFF0FDF4),
            const Color(0xFF86EFAC),
            onTap: () => controller.setDirectoryFilter('Online'),
          ),
          const SizedBox(width: 6),
          tile(
            'Offline',
            '$offline',
            'Offline',
            const Color(0xFF64748B),
            const Color(0xFFF8FAFC),
            const Color(0xFFCBD5E1),
            onTap: () => controller.setDirectoryFilter('Offline'),
          ),
          const SizedBox(width: 6),
          tile(
            'Locked',
            '$locked',
            'Locked',
            const Color(0xFFDC2626),
            const Color(0xFFFEF2F2),
            const Color(0xFFFCA5A5),
            onTap: () => controller.setDirectoryFilter('Locked'),
          ),
          const SizedBox(width: 6),
          tile(
            'Attention',
            '$attention',
            'Attention',
            const Color(0xFFD97706),
            const Color(0xFFFEF3C7),
            const Color(0xFFFDE68A),
            onTap: () => controller.setDirectoryFilter('Attention'),
          ),
        ],
      );
    });
  }
}

class _SearchField extends GetView<StudentScreenTimeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSearching = controller.isSearchingServer.value;
      final hasText = controller.searchText.value.isNotEmpty;

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: controller.searchFilterController,
          onChanged: controller.onSearchChanged,
          onSubmitted: controller.onSearchSubmitted,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search by name, room, Aadhar or phone...',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF0284C7),
              size: 22,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                if (hasText)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: controller.clearSearch,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _StudentRow extends GetView<StudentScreenTimeController> {
  final dynamic student;
  const _StudentRow({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final name = (student['name'] ?? student['fullName'] ?? 'Student')
        .toString();
    final room =
        (student['room'] ??
                student['room_number'] ??
                student['roomNumber'] ??
                'N/A')
            .toString();
    final isOnline = StudentScreenTimeController.isStudentOnline(student);
    final isScreenOn = StudentScreenTimeController.isStudentScreenOn(student);
    final totalMins = StudentScreenTimeController.toInt(
      student['totalScreenTimeMinutes'] ??
          student['todayScreenTimeMinutes'] ??
          student['today_minutes'] ??
          student['total_screen_time_minutes'] ??
          student['minutes'] ??
          0,
    );
    final nightMins = StudentScreenTimeController.toInt(
      student['nightScreenTimeMinutes'],
    );
    final locked = StudentScreenTimeController.isStudentLocked(student);
    final restricted = StudentScreenTimeController.blockedOf(student).length;
    final tampered = StudentScreenTimeController.isStudentTampered(student);
    final lastSeen = StudentScreenTimeController.lastSeenOf(student);
    final currentApp = (student['currentApp'] ?? '').toString();
    final currentPkg = (student['currentPackage'] ?? '').toString();

    final statusColor = isOnline
        ? (isScreenOn ? const Color(0xFF16A34A) : const Color(0xFFD97706))
        : const Color(0xFF94A3B8);
    final statusText = isOnline
        ? (isScreenOn
              ? (currentApp.isNotEmpty && currentApp != 'Idle'
                    ? 'Using $currentApp'
                    : 'Screen on')
              : 'Standby')
        : (lastSeen != null
              ? 'Seen ${StudentScreenTimeController.relativeTime(lastSeen)}'
              : 'Offline');

    final initials = name.trim().isNotEmpty
        ? name
              .trim()
              .split(RegExp(r'\s+'))
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'S';

    final avatarBg = tampered
        ? const Color(0xFFFEF3C7)
        : (locked ? const Color(0xFFFEF2F2) : const Color(0xFFE0F2FE));
    final avatarBorder = tampered
        ? const Color(0xFFFDE68A)
        : (locked ? const Color(0xFFFCA5A5) : const Color(0xFFBAE6FD));
    final avatarText = tampered
        ? const Color(0xFFD97706)
        : (locked ? const Color(0xFFDC2626) : const Color(0xFF0284C7));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked
              ? const Color(0xFFFCA5A5)
              : (tampered ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.selectStudent(student),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // Avatar + presence dot (or active app icon)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: avatarBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: avatarText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: isScreenOn && currentPkg.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: AppBrandIcon(
                                packageName: currentPkg,
                                appName: currentApp,
                                size: 18,
                                showBadge: false,
                              ),
                            )
                          : Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
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
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Room $room',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
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
                              const _Tag(
                                icon: Icons.gpp_bad_rounded,
                                label: 'Monitoring off',
                                color: Color(0xFFD97706),
                                bg: Color(0xFFFEF3C7),
                              ),
                            if (locked)
                              const _Tag(
                                icon: Icons.lock_rounded,
                                label: 'Locked',
                                color: Color(0xFFDC2626),
                                bg: Color(0xFFFEF2F2),
                              ),
                            if (restricted > 0 && !locked)
                              _Tag(
                                icon: Icons.block_rounded,
                                label: '$restricted blocked',
                                color: const Color(0xFF0284C7),
                                bg: const Color(0xFFE0F2FE),
                              ),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    if (nightMins > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.nightlight_round,
                            size: 11,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${nightMins}m night',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  const _Tag({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
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
      final accentColor = isActive
          ? const Color(0xFF16A34A)
          : const Color(0xFFD97706);
      final accentBg = isActive
          ? const Color(0xFFF0FDF4)
          : const Color(0xFFFEF3C7);
      final accentBorder = isActive
          ? const Color(0xFF86EFAC)
          : const Color(0xFFFDE68A);

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.035),
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
                color: accentBg,
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
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // const SizedBox(width: 8),
                      // StatusBadge(
                      //   label: isActive ? 'ACTIVE' : 'TURNED OFF',
                      //   color: accentColor,
                      //   icon: isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                      // ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            policy.formatTimeRange(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () =>
                            _showEditCurfewHours(context, controller, policy),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            'Edit Hours',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF0284C7),
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
              onPressed: isUpdating
                  ? null
                  : () => controller.toggleGlobalCurfew(!isActive),
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
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFF0284C7),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Set Global Curfew Hours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () => Get.back(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Applies to all hostel students. Phones evaluate curfew boundaries during this window.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),
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
                      const SizedBox(width: 12),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Get.back();
                            controller.updateGlobalCurfewTimes(start, end);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Hours',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.edit_calendar_rounded,
                  size: 16,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUpdating)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFDC2626),
                    ),
                  )
                else
                  const Icon(
                    Icons.power_settings_new_rounded,
                    size: 15,
                    color: Color(0xFFDC2626),
                  ),
                const SizedBox(width: 6),
                const Text(
                  'Turn OFF',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              ),
              borderRadius: BorderRadius.circular(20),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.power_settings_new_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                const SizedBox(width: 6),
                const Text(
                  'Turn ON',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
