import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/room_keys/room_key_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/stat_strip.dart';
import '../controllers/room_keys_controller.dart';
import '../widgets/room_key_widgets.dart';

/// Operator → Room Keys: every room with its door and cupboard key numbers.
class RoomKeysScreen extends GetView<RoomKeysController> {
  const RoomKeysScreen({super.key});

  void _openRoom(String room) => Get.toNamed(Routes.operatorRoomKeysRoom, arguments: room);

  /// A room with no students yet (or not in the list): ask for its number.
  Future<void> _openOtherRoom() async {
    final text = TextEditingController();
    final room = await Get.dialog<String>(
      Builder(
        builder: (ctx) => AlertDialog(
          title: const Text('Which room?'),
          content: TextField(
            controller: text,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Room number', hintText: 'e.g. 204'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(text.text), child: const Text('Open')),
          ],
        ),
      ),
    );
    text.dispose();
    final number = normalizeRoom(room);
    if (number.isNotEmpty) _openRoom(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openOtherRoom,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Another room'),
      ),
      body: AppRefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverGradientHeader(
              overline: 'Hostel office',
              title: 'Room Keys',
              subtitle: 'Door and cupboard keys of every room',
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              child: Obx(() => HeaderPill(icon: Icons.key_rounded, label: '${controller.keys.length} keys')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapLg,
                  AppDimens.screenPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Obx(
                      () => StatStrip(
                        items: [
                          StatStripItem(
                            value: '${controller.keyCount(KeyStatus.assigned)}',
                            label: 'With students',
                            color: KeyStatus.assigned.color,
                          ),
                          StatStripItem(
                            value: '${controller.keyCount(KeyStatus.office)}',
                            label: 'In office',
                            color: KeyStatus.office.color,
                          ),
                          StatStripItem(
                            value: '${controller.keyCount(KeyStatus.lost)}',
                            label: 'Lost',
                            color: KeyStatus.lost.color,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    AppTextField(
                      label: 'Search',
                      hint: 'Room, key number or student',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (v) => controller.search.value = v,
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    Obx(() {
                      final f = controller.filter.value;
                      Widget chip(String label, RoomFilter value) => Padding(
                        padding: const EdgeInsets.only(right: AppDimens.gapSm),
                        child: ChoiceChip(
                          label: Text('$label (${controller.roomCount(value)})'),
                          selected: f == value,
                          onSelected: (_) => controller.filter.value = value,
                        ),
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            chip('All rooms', RoomFilter.all),
                            chip('Missing keys', RoomFilter.missing),
                            chip('Needs attention', RoomFilter.attention),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Obx(() {
              if (controller.isLoading.value) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (controller.hasError.value) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load room keys',
                    message: controller.errorMessage.value,
                    actionLabel: 'Retry',
                    onAction: controller.load,
                  ),
                );
              }
              final rooms = controller.visibleRooms;
              if (rooms.isEmpty) {
                final none = controller.rooms.isEmpty;
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.key_off_rounded,
                    title: none ? 'No rooms yet' : 'Nothing here',
                    message: none
                        ? 'Rooms appear here from the student list. Open a room to add its keys.'
                        : 'Try another search or filter.',
                    actionLabel: none ? 'Open a room' : null,
                    onAction: none ? _openOtherRoom : null,
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapLg,
                  AppDimens.screenPadding,
                  110,
                ),
                sliver: SliverList.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapSm),
                  itemBuilder: (_, i) => _RoomCard(room: rooms[i], onTap: () => _openRoom(rooms[i].number)),
                ),
              );
            }),
          ],
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
    final lines = <String>[
      '$students ${students == 1 ? 'student' : 'students'}',
      door == null ? 'No door key' : 'Door $door (${room.doorKeys.length})',
      if (students > 0)
        'Cupboards $withCupboard/$students'
      else if (room.cupboardKeys.isNotEmpty)
        '${room.cupboardKeys.length} cupboard ${room.cupboardKeys.length == 1 ? 'key' : 'keys'}',
    ];
    final warnings = <(String, Color)>[
      if (!room.hasDoorKey) ('No door key', AppColors.warningOrange),
      if (room.studentsWithoutCupboard.isNotEmpty)
        ('${room.studentsWithoutCupboard.length} without cupboard key', AppColors.warningOrange),
      if (room.attentionCount > 0) ('${room.attentionCount} to check', AppColors.cancelledRed),
    ];

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimens.gapMd),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 56),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Text(
              room.number,
              style: AppTextStyles.title.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Room ${room.number}', style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text(lines.join(' · '), style: AppTextStyles.bodySm),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final (text, color) in warnings)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                          ),
                          child: Text(
                            text,
                            style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
