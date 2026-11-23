import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/geofence/geofence_policy_model.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/screen_time_directory_controller.dart';
import '../controllers/screen_time_utils.dart';
import '../curfew/curfew_admin_entry.dart';
import '../../../core/utils/string_formatting.dart';
import 'app_brand_icon.dart';
import 'app_install_status_pill.dart';
import 'app_requests_banner.dart';
import '../../shared/widgets/student_avatar.dart';

/// Warden's directory: search, quick filters and one row per student that
/// answers "is this phone online, is it compliant, how much was it used?"
///
/// This is a sliver: the rows are built lazily by a [SliverList] inside the
/// screen's own scroll view, so only the rows on screen exist however many
/// students are loaded.
class StudentDirectoryView extends GetView<ScreenTimeDirectoryController> {
  const StudentDirectoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardEntries(),
              const SizedBox(height: 10),
              const _GlobalCurfewBanner(),
              const SizedBox(height: 10),
              AppRequestsBanner(host: controller),
              _SummaryStrip(),
              const SizedBox(height: 10),
              _SearchField(),
              const _LeaderGroupBanner(),
              const _GroupQuickFilter(),
              const SizedBox(height: 12),
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
      if (controller.leaderGroupMissing.value) {
        return const SliverToBoxAdapter(
          child: AppCard(
            child: EmptyState(
              icon: Icons.groups_2_outlined,
              title: 'Your group is not set',
              message: 'Ask the hostel office to set your group. Then the students of your group appear here.',
            ),
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
class _SummaryStrip extends GetView<ScreenTimeDirectoryController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.directoryFilter.value;
      final total = controller.directoryCount('All');
      final online = controller.directoryCount('Online');
      final offline = controller.directoryCount('Offline');
      final locked = controller.directoryCount('Locked');
      final attention = controller.directoryCount('Attention');

      Widget item({
        required String filter,
        required String count,
        required String label,
        Color? dotColor,
      }) {
        final selected = active == filter;
        return Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.setDirectoryFilter(filter),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0284C7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dotColor != null && !selected) ...[
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            count,
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            item(
              filter: 'All',
              count: '$total',
              label: 'Total',
            ),
            _divider(),
            item(
              filter: 'Online',
              count: '$online',
              label: 'Online',
              dotColor: const Color(0xFF16A34A),
            ),
            _divider(),
            item(
              filter: 'Offline',
              count: '$offline',
              label: 'Offline',
            ),
            _divider(),
            item(
              filter: 'Locked',
              count: controller.directoryCountIsPartial('Locked') ? '$locked+' : '$locked',
              label: 'Locked',
              dotColor: locked > 0 ? const Color(0xFFDC2626) : null,
            ),
            _divider(),
            item(
              filter: 'Attention',
              count: controller.directoryCountIsPartial('Attention') ? '$attention+' : '$attention',
              label: 'Attention',
              dotColor: attention > 0 ? const Color(0xFFD97706) : null,
            ),
          ],
        ),
      );
    });
  }

  static Widget _divider() {
    return Container(
      width: 1,
      height: 20,
      color: const Color(0xFFF1F5F9),
    );
  }
}

class _SearchField extends GetView<ScreenTimeDirectoryController> {
  const _SearchField();

  Widget _filterSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF0284C7)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.85],
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Drag Handle & Top Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                            child: Column(
                              children: [
                                Center(
                                  child: Container(
                                    width: 44,
                                    height: 4.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Filter & Sort Screen Time',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Refine by wings, floors, device status, and usage',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Obx(() {
                                      if (controller.activeFilterCount == 0) return const SizedBox.shrink();
                                      return TextButton(
                                        onPressed: () {
                                          controller.resetAllFilters();
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                        child: const Text(
                                          'Reset All',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      );
                                    }),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                                      tooltip: 'Close',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ],
                      ),
                    ),

                    // Scrollable Content
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      sliver: SliverToBoxAdapter(
                        child: Obx(() {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. DEVICE & SECURITY STATUS
                              _filterSectionHeader('DEVICE & SECURITY STATUS', Icons.devices_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ScreenTimeDirectoryController.directoryFilters.map((df) {
                                  final sel = controller.directoryFilter.value == df;
                                  final color = df == 'Locked'
                                      ? const Color(0xFFDC2626)
                                      : df == 'Attention'
                                          ? const Color(0xFFD97706)
                                          : df == 'Online'
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF0284C7);
                                  return FilterChip(
                                    label: Text(df),
                                    selected: sel,
                                    selectedColor: color,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? color : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.setDirectoryFilter(df),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // 2. WING / GROUP (not for a leader: their list is their group)
                              if (!controller.isLeaderView) ...[
                              _filterSectionHeader('HOSTEL WING / GROUP', Icons.apartment_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ScreenTimeDirectoryController.hshGroups.map((g) {
                                  final sel = controller.selectedGroup.value == g;
                                  const color = Color(0xFF0284C7);
                                  return FilterChip(
                                    label: Text(g),
                                    selected: sel,
                                    selectedColor: color,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? color : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.selectGroup(g),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              ],

                              // 3. FLOOR SELECTOR
                              _filterSectionHeader('HOSTEL FLOOR', Icons.layers_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ScreenTimeDirectoryController.floorOptions.map((f) {
                                  final sel = controller.selectedFloor.value == f;
                                  return FilterChip(
                                    label: Text(f),
                                    selected: sel,
                                    selectedColor: const Color(0xFF0284C7),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.selectFloor(f),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // 4. RESIDENCE STATUS
                              _filterSectionHeader('RESIDENCE STATUS', Icons.badge_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ScreenTimeDirectoryController.statusOptions.map((s) {
                                  final sel = controller.selectedStatus.value == s;
                                  return FilterChip(
                                    label: Text(s),
                                    selected: sel,
                                    selectedColor: const Color(0xFF059669),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.selectStatus(s),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // SORT ORDER
                              _filterSectionHeader('SORT STUDENTS BY', Icons.sort_by_alpha_rounded),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ScreenTimeDirectoryController.sortOptions.map((s) {
                                  final sel = controller.selectedSort.value == s;
                                  return ChoiceChip(
                                    label: Text(s),
                                    selected: sel,
                                    selectedColor: const Color(0xFF0F172A),
                                    labelStyle: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFF334155),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: sel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (v) => controller.selectSort(s),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Sticky Action Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Obx(() {
                        final count = controller.filteredStudents.length;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Apply Filters & Show ($count Students)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSearching = controller.isSearchingServer.value;
      final hasText = controller.searchText.value.isNotEmpty;

      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
            ),
          ),
          const SizedBox(width: 8),
          Obx(() {
            final count = controller.activeFilterCount;
            return Material(
              color: count > 0 ? const Color(0xFF0284C7) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: count > 0 ? 2 : 0,
              shadowColor: count > 0 ? const Color(0xFF0284C7).withValues(alpha: 0.3) : Colors.black12,
              child: InkWell(
                key: const ValueKey('screentime_directory_filter_button'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showFilterBottomSheet(context),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: count > 0 ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: count > 0 ? Colors.white : const Color(0xFF0284C7),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      );
    });
  }
}

/// A leader's list is their own group only; this says which group.
class _LeaderGroupBanner extends GetView<ScreenTimeDirectoryController> {
  const _LeaderGroupBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final group = controller.leaderGroupName.value;
      if (!controller.isLeaderView || group == null || group.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, size: 20, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$group group',
                      style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'You see only the students of your group.',
                      style: TextStyle(color: Color(0xFF0284C7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Admins and wardens: the counterpart of a leader's "My Group" banner. One
/// tap narrows the list to a group (tap again for everyone); the picked group
/// shows how many of its students are loaded.
class _GroupQuickFilter extends GetView<ScreenTimeDirectoryController> {
  const _GroupQuickFilter();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.currentRole.value.canOperate) return const SizedBox.shrink();
      final selected = controller.selectedGroup.value;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final g in ScreenTimeDirectoryController.hshGroups)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _GroupChip(
                    label: g == 'All' ? 'All groups' : g,
                    count: g != 'All' && g == selected ? controller.groupCountLabel(g) : null,
                    selected: g == selected,
                    onTap: () => controller.selectGroup(g),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  const _GroupChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0284C7) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != 'All groups') ...[
                Icon(
                  Icons.groups_rounded,
                  size: 14,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF334155),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count!,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF475569),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends GetView<ScreenTimeDirectoryController> {
  final dynamic student;
  const _StudentRow({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final rawName = (student['name'] ?? student['fullName'] ?? 'Student')
        .toString();
    final name = formatPersonName(rawName);
    final room =
        (student['room'] ??
                student['room_number'] ??
                student['roomNumber'] ??
                'N/A')
            .toString();
    final isOnline = isStudentOnline(student);
    final isScreenOn = isStudentScreenOn(student);
    final totalMins = extractStudentMinutes(student);
    final nightMins = extractStudentNightMinutes(student);
    final locked = isStudentLocked(student);
    final restricted = blockedOf(student).length;
    final lastSeen = lastSeenOf(student);
    final currentApp = (student['currentApp'] ?? '').toString();
    final currentPkg = (student['currentPackage'] ?? '').toString();

    final rawBattery = student['batteryLevel'] ??
        student['battery_level'] ??
        student['battery'] ??
        (student['compliance'] is Map
            ? (student['compliance']['batteryLevel'] ??
                student['compliance']['battery_level'])
            : null);
    final battery = rawBattery != null ? toInt(rawBattery) : -1;
    final isCharging = toBool(
        student['isCharging'] ??
        student['is_charging'] ??
        (student['compliance'] is Map
            ? (student['compliance']['isCharging'] ??
                student['compliance']['is_charging'])
            : false));

    final passUntil = student['installPassUntil'] ??
        student['install_pass_until'] ??
        (student['policy'] is Map
            ? (student['policy']['installPassUntil'] ??
                student['policy']['install_pass_until'])
            : null);
    final hasInstallPass = passUntil != null &&
        toInt(passUntil) > DateTime.now().millisecondsSinceEpoch;

    final lowBattery = isStudentLowBattery(student);
    final isDisconnected = isStudentDisconnected(student);
    final extendedOffline = isStudentExtendedOffline(student);

    final statusColor = isOnline
        ? (isScreenOn ? const Color(0xFF16A34A) : const Color(0xFFD97706))
        : (isDisconnected ? const Color(0xFFEA580C) : const Color(0xFF94A3B8));
    final statusText = isOnline
        ? (isScreenOn
              ? (currentApp.isNotEmpty && currentApp != 'Idle'
                    ? 'Using $currentApp'
                    : 'Screen on')
              : 'Standby')
        : (lastSeen != null
              ? (isDisconnected
                    ? 'Offline since ${DateFormat('h:mm a').format(lastSeen)}'
                    : 'Seen ${relativeTime(lastSeen)}')
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

    // Monitoring status (permissions) is shown on the student's own page only.
    final avatarBg = locked ? const Color(0xFFFEF2F2) : const Color(0xFFE0F2FE);
    final avatarBorder = locked ? const Color(0xFFFCA5A5) : const Color(0xFFBAE6FD);
    final avatarText = locked ? const Color(0xFFDC2626) : const Color(0xFF0284C7);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
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
                    // The list's `aadhar` is the bank code (0768) for most
                    // students; only a full 12-digit one is used directly.
                    StudentAvatar(
                      name: name,
                      aadhar: student['aadhar']?.toString(),
                      bankCode: student['aadhar']?.toString(),
                      size: 44,
                      circle: false,
                      background: avatarBg,
                      borderColor: avatarBorder,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (battery >= 0) ...[
                            const SizedBox(width: 6),
                            _DirectoryBatteryPill(
                              level: battery,
                              isCharging: isCharging,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      AppInstallStatusPill(status: appInstallStatusOf(student), compact: true),
                      if (locked || restricted > 0 || hasInstallPass || lowBattery || isDisconnected || extendedOffline) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isDisconnected)
                              _Tag(
                                icon: Icons.wifi_off_rounded,
                                label: lastSeen != null
                                    ? 'Disconnected (${DateFormat('h:mm a').format(lastSeen)})'
                                    : 'Disconnected (>15m)',
                                color: const Color(0xFFDC2626),
                                bg: const Color(0xFFFEF2F2),
                              ),
                            if (lowBattery)
                              _Tag(
                                icon: Icons.battery_alert_rounded,
                                label: 'Low battery ($battery%)',
                                color: const Color(0xFFDC2626),
                                bg: const Color(0xFFFEF2F2),
                              ),
                            if (extendedOffline && !isDisconnected)
                              _Tag(
                                icon: Icons.cloud_off_rounded,
                                label: lastSeen != null
                                    ? 'Offline (${relativeTime(lastSeen)})'
                                    : 'Offline (>12h)',
                                color: const Color(0xFFD97706),
                                bg: const Color(0xFFFEF3C7),
                              ),
                            if (hasInstallPass)
                              const _Tag(
                                icon: Icons.install_mobile_rounded,
                                label: 'Install pass',
                                color: Color(0xFF0284C7),
                                bg: Color(0xFFE0F2FE),
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
                      formatMinutes(totalMins),
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
/// Overview (every supervisor; leaders see their group) and Curfew sessions
/// (wardens and admins only).
class _DashboardEntries extends GetView<ScreenTimeDirectoryController> {
  const _DashboardEntries();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canManage = controller.currentRole.value.canOperate;
      return Row(
        children: [
          Expanded(
            child: _EntryButton(
              key: const ValueKey('screentime_overview_entry'),
              icon: Icons.dashboard_outlined,
              label: 'Overview',
              onTap: () => CurfewAdminEntry.openOverview(context, canManageSessions: canManage),
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _EntryButton(
                key: const ValueKey('screentime_sessions_entry'),
                icon: Icons.nightlight_outlined,
                label: 'Curfew sessions',
                onTap: () => CurfewAdminEntry.openSessions(context),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalCurfewBanner extends GetView<ScreenTimeDirectoryController> {
  const _GlobalCurfewBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final policy = controller.globalCurfewPolicy.value;
      final isActive = policy.isActive;
      final isUpdating = controller.isUpdatingCurfew.value;

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                isActive ? Icons.nightlight_round : Icons.bedtime_off_outlined,
                color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Night Curfew',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Off',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
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
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () =>
                            _showEditCurfewHours(context, controller, policy),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          child: Text(
                            'Edit Hours',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
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
            SizedBox(
              height: 32,
              child: isUpdating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0284C7),
                      ),
                    )
                  : Switch.adaptive(
                      value: isActive,
                      onChanged: (val) => controller.toggleGlobalCurfew(val),
                      activeThumbColor: const Color(0xFF16A34A),
                      activeTrackColor: const Color(0xFFDCFCE7),
                      inactiveThumbColor: const Color(0xFF94A3B8),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                    ),
            ),
          ],
        ),
      );
    });
  }

  void _showEditCurfewHours(
    BuildContext context,
    ScreenTimeDirectoryController controller,
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

class _DirectoryBatteryPill extends StatelessWidget {
  final int level;
  final bool isCharging;
  const _DirectoryBatteryPill({required this.level, required this.isCharging});

  @override
  Widget build(BuildContext context) {
    final isLow = level <= 20;
    final isModerate = level <= 35;
    final color = isLow
        ? const Color(0xFFDC2626)
        : (isModerate ? const Color(0xFFD97706) : const Color(0xFF16A34A));
    final bg = isLow
        ? const Color(0xFFFEF2F2)
        : (isModerate ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4));

    final IconData icon = isCharging
        ? Icons.battery_charging_full_rounded
        : (level <= 15 ? Icons.battery_alert_rounded : Icons.battery_full_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2.5),
          Text(
            '$level%',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
