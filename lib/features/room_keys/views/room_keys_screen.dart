import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/room_keys/room_key_models.dart';
import '../../shared/widgets/empty_state.dart';
import '../controllers/room_keys_controller.dart';

/// Operator → Room Keys: every room with its door and cupboard key numbers,
/// styled to match the Hostel Phonebook navy-and-slate theme.
class RoomKeysScreen extends GetView<RoomKeysController> {
  const RoomKeysScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _blue = Color(0xFF0284C7);
  static const Color _blueSoft = Color(0xFFE0F2FE);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _slate = Color(0xFF475569);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _amber = Color(0xFFD97706);
  static const Color _green = Color(0xFF059669);
  static const Color _red = Color(0xFFDC2626);

  void _openRoom(String room) => Get.toNamed(Routes.operatorRoomKeysRoom, arguments: room);

  /// A room with no students yet (or not in the list): ask for its number.
  Future<void> _openOtherRoom() async {
    final text = TextEditingController();
    final room = await Get.dialog<String>(
      Builder(
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Open another room',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          content: TextField(
            controller: text,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Room number',
              hintText: 'e.g. 204',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(text.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    final number = normalizeRoom(room);
    if (number.isNotEmpty) _openRoom(number);
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Obx(() {
              final floors = controller.availableFloors;
              final activeCount = controller.activeFilterCount;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: _blueSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: _blue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Rooms',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            Text(
                              'Refine by key status and hostel floor',
                              style: TextStyle(fontSize: 11.5, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      if (activeCount > 0)
                        TextButton(
                          onPressed: controller.resetFilters,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text(
                            'Reset All',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _muted, size: 22),
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: _border),
                  _sheetSectionHeader('ROOM STATUS', Icons.vpn_key_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sheetChip(
                        label: 'All rooms (${controller.roomCount(RoomFilter.all)})',
                        selected: controller.filter.value == RoomFilter.all,
                        color: _blue,
                        onTap: () => controller.filter.value = RoomFilter.all,
                      ),
                      _sheetChip(
                        label: 'Missing keys (${controller.roomCount(RoomFilter.missing)})',
                        selected: controller.filter.value == RoomFilter.missing,
                        color: _amber,
                        onTap: () => controller.filter.value = RoomFilter.missing,
                      ),
                      _sheetChip(
                        label: 'Needs attention (${controller.roomCount(RoomFilter.attention)})',
                        selected: controller.filter.value == RoomFilter.attention,
                        color: _red,
                        onTap: () => controller.filter.value = RoomFilter.attention,
                      ),
                    ],
                  ),
                  if (floors.length > 1) ...[
                    const SizedBox(height: 20),
                    _sheetSectionHeader('HOSTEL FLOOR', Icons.layers_rounded),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in floors)
                          _sheetChip(
                            label: f,
                            selected: controller.selectedFloor.value == f,
                            color: _blue,
                            onTap: () => controller.selectedFloor.value = f,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Show ${controller.visibleRooms.length} ${controller.visibleRooms.length == 1 ? 'Room' : 'Rooms'}',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  static Widget _sheetSectionHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 15, color: _muted),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: _slate,
          letterSpacing: 0.7,
        ),
      ),
    ],
  );

  static Widget _sheetChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) => FilterChip(
    label: Text(label),
    selected: selected,
    selectedColor: color,
    checkmarkColor: Colors.white,
    labelStyle: TextStyle(
      color: selected ? Colors.white : const Color(0xFF334155),
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      fontSize: 12.5,
    ),
    backgroundColor: const Color(0xFFF1F5F9),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? color : _border),
    ),
    onSelected: (_) => onTap(),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openOtherRoom,
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Another room', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: RefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          color: _blue,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _RoomKeysHeaderDelegate(
                  controller: controller,
                  topPadding: MediaQuery.of(context).padding.top,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Count cards matching Phonebook card design
                      Obx(
                        () => Row(
                          children: [
                            Expanded(
                              child: _CountCard(
                                value: '${controller.keyCount(KeyStatus.assigned)}',
                                label: 'With students',
                                icon: Icons.person_outline_rounded,
                                color: _green,
                                bgColor: const Color(0xFFECFDF5),
                                onTap: () => controller.filter.value = RoomFilter.all,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CountCard(
                                value: '${controller.keyCount(KeyStatus.office)}',
                                label: 'In office',
                                icon: Icons.vpn_key_outlined,
                                color: _blue,
                                bgColor: _blueSoft,
                                onTap: () => controller.filter.value = RoomFilter.all,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CountCard(
                                value: '${controller.keyCount(KeyStatus.lost)}',
                                label: 'Lost',
                                icon: Icons.report_problem_outlined,
                                color: _red,
                                bgColor: const Color(0xFFFEF2F2),
                                highlighted: controller.filter.value == RoomFilter.attention,
                                onTap: () {
                                  controller.filter.value =
                                      controller.filter.value == RoomFilter.attention
                                          ? RoomFilter.all
                                          : RoomFilter.attention;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Search bar + Filter launcher button (exact Phonebook style)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _border),
                                boxShadow: [
                                  BoxShadow(
                                    color: _ink.withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: controller.searchController,
                                onChanged: controller.onSearchChanged,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search room, key number or student...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: _blue,
                                    size: 22,
                                  ),
                                  suffixIcon: Obx(() {
                                    if (controller.search.value.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: _muted,
                                      ),
                                      onPressed: controller.clearSearch,
                                    );
                                  }),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Obx(() {
                            final count = controller.activeFilterCount;
                            return Material(
                              color: count > 0 ? _blue : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              elevation: count > 0 ? 3 : 1,
                              shadowColor: count > 0 ? _blue.withValues(alpha: 0.3) : Colors.black12,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showFilterBottomSheet(context),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: count > 0 ? _blue : _border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        size: 20,
                                        color: count > 0 ? Colors.white : _blue,
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
                                              color: _blue,
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
                      ),
                      const SizedBox(height: 12),

                      // Filter pill tabs (exact Phonebook AnimatedContainer style)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Obx(() {
                          final current = controller.filter.value;
                          return Row(
                            children: [
                              _FilterPillTab(
                                label: 'All rooms (${controller.roomCount(RoomFilter.all)})',
                                selected: current == RoomFilter.all,
                                color: _blue,
                                onTap: () => controller.filter.value = RoomFilter.all,
                              ),
                              _FilterPillTab(
                                label: 'Missing keys (${controller.roomCount(RoomFilter.missing)})',
                                icon: Icons.key_off_rounded,
                                selected: current == RoomFilter.missing,
                                color: _amber,
                                onTap: () => controller.filter.value = RoomFilter.missing,
                              ),
                              _FilterPillTab(
                                label: 'Needs attention (${controller.roomCount(RoomFilter.attention)})',
                                icon: Icons.warning_amber_rounded,
                                selected: current == RoomFilter.attention,
                                color: _red,
                                onTap: () => controller.filter.value = RoomFilter.attention,
                              ),
                            ],
                          );
                        }),
                      ),

                      // Active floor chip when narrowed via Filter sheet
                      Obx(() {
                        final floor = controller.selectedFloor.value;
                        if (floor == 'All') return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                            decoration: BoxDecoration(
                              color: _blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _blue.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers_rounded, size: 13, color: _blue),
                                const SizedBox(width: 5),
                                Text(
                                  floor,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _blue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => controller.selectedFloor.value = 'All',
                                  borderRadius: BorderRadius.circular(10),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.close_rounded, size: 14, color: _blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Section header matching Phonebook's amber accent bar
                      Obx(() {
                        final count = controller.visibleRooms.length;
                        return Row(
                          children: [
                            Container(
                              width: 20,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: _amber,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'HOSTEL ROOMS ($count)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _slate,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            if (controller.activeFilterCount > 0)
                              InkWell(
                                onTap: controller.resetFilters,
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: Text(
                                    'Clear filters',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _blue,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(color: _blue)),
                  );
                }
                if (controller.hasError.value) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load room keys',
                        message: controller.errorMessage.value,
                        actionLabel: 'Retry',
                        onAction: controller.load,
                      ),
                    ),
                  );
                }
                final rooms = controller.visibleRooms;
                if (rooms.isEmpty) {
                  final none = controller.rooms.isEmpty;
                  final hasFilters =
                      controller.activeFilterCount > 0 || controller.search.value.trim().isNotEmpty;
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: EmptyState(
                        icon: Icons.key_off_rounded,
                        title: none ? 'No rooms yet' : 'Nothing here',
                        message: none
                            ? 'Rooms appear here from the student list. Open a room to add its keys.'
                            : 'Try another search or filter.',
                        actionLabel: none
                            ? 'Open a room'
                            : (hasFilters ? 'Clear Filters' : null),
                        onAction: none
                            ? _openOtherRoom
                            : (hasFilters
                                ? () {
                                    controller.clearSearch();
                                    controller.resetFilters();
                                  }
                                : null),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverList.separated(
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _RoomCard(
                      room: rooms[i],
                      onTap: () => _openRoom(rooms[i].number),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool highlighted;
  final VoidCallback? onTap;

  const _CountCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? color.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
              width: highlighted ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (highlighted ? color : const Color(0xFF0F172A)).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 15, color: color),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPillTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterPillTab({
    required this.label,
    this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? color : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color: selected ? Colors.white : color,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final KeyRoom room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final students = room.students.length;
    final withCupboard = students - room.studentsWithoutCupboard.length;
    final door = room.doorNumber;
    String cupboardSummary;
    final hasA = room.cupboardA != null;
    final hasB = room.cupboardB != null;
    if (students == 2 && (hasA || hasB)) {
      if (hasA && hasB) {
        cupboardSummary = 'Cupboards A & B';
      } else if (hasA) {
        cupboardSummary = 'Cupboard A (B missing)';
      } else {
        cupboardSummary = 'Cupboard B (A missing)';
      }
    } else if (students > 0) {
      cupboardSummary = 'Cupboards $withCupboard/$students';
    } else if (room.cupboardKeys.isNotEmpty) {
      cupboardSummary = '${room.cupboardKeys.length} cupboard ${room.cupboardKeys.length == 1 ? 'key' : 'keys'}';
    } else {
      cupboardSummary = 'No cupboards';
    }

    final lines = <String>[
      '$students ${students == 1 ? 'student' : 'students'}',
      door == null ? 'No door key' : 'Door $door (${room.doorKeys.length})',
      cupboardSummary,
    ];
    final warnings = <(String, Color, Color)>[
      if (!room.hasDoorKey) ('No door key', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      if (room.studentsWithoutCupboard.isNotEmpty)
        (
          '${room.studentsWithoutCupboard.length} without cupboard key',
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
        ),
      if (room.attentionCount > 0)
        ('${room.attentionCount} to check', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 54),
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                ),
                child: Text(
                  room.number,
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${room.number}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lines.join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (warnings.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final (text, fg, bg) in warnings)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: fg.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned navy-to-ocean header matching `_PhonebookHeaderDelegate` in PhonebookScreen.
class _RoomKeysHeaderDelegate extends SliverPersistentHeaderDelegate {
  final RoomKeysController controller;
  final double topPadding;
  final VoidCallback onBack;

  _RoomKeysHeaderDelegate({
    required this.controller,
    required this.topPadding,
    required this.onBack,
  });

  @override
  double get minExtent => topPadding + 60.0;

  @override
  double get maxExtent => topPadding + 164.0;

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    Widget? child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            alignment: Alignment.center,
            child: child ?? Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular((28.0 * (1.0 - progress)).clamp(0.0, 28.0));

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
            Positioned.fill(
              child: CustomPaint(painter: _RoomKeysOrbPainter()),
            ),
            // Top sticky action bar
            Positioned(
              top: topPadding + 6,
              left: 14,
              right: 14,
              height: 48,
              child: Row(
                children: [
                  _roundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: const Text(
                        'Room Keys',
                        style: TextStyle(
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
                  Obx(() {
                    final loading = controller.isLoading.value;
                    return _roundButton(
                      icon: Icons.sync_rounded,
                      tooltip: 'Refresh keys',
                      onTap: loading ? null : () => controller.load(showLoading: false),
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    );
                  }),
                ],
              ),
            ),
            // Hero expanded title & status pills
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Opacity(
                opacity: expandedOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'HOSTEL OFFICE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Room Keys',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _statusPill(Icons.key_rounded, '${controller.keys.length} keys'),
                          _statusPill(
                            Icons.meeting_room_rounded,
                            '${controller.rooms.length} ${controller.rooms.length == 1 ? 'room' : 'rooms'}',
                          ),
                        ],
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
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _RoomKeysOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.86, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
