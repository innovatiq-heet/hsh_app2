import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/room_keys/room_key_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/gradient_header.dart';
import '../controllers/room_keys_controller.dart';
import '../widgets/room_key_widgets.dart';

/// One room: its door keys, each student with their cupboard key, and any
/// other cupboard keys (office, lost, or with someone who moved out).
class RoomKeysRoomScreen extends GetView<RoomKeysController> {
  final String room;

  const RoomKeysRoomScreen({super.key, required this.room});

  String get _number => normalizeRoom(room);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RoomKeysSetupSheet.show(controller, _number),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add keys'),
      ),
      body: AppRefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverGradientHeader(
              overline: 'Room Keys',
              title: 'Room $_number',
              subtitle: 'Door and cupboard keys, by number',
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              child: Obx(() {
                final r = controller.room(_number);
                return HeaderPill(
                  icon: Icons.key_rounded,
                  label: '${r.keys.length} keys · ${r.students.length} students',
                );
              }),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapLg,
                AppDimens.screenPadding,
                110,
              ),
              sliver: SliverToBoxAdapter(child: Obx(() => _content(controller.room(_number)))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(KeyRoom r) {
    if (controller.isLoading.value && controller.keys.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppDimens.gapXl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final busy = controller.busyIds;
    Widget tile(RoomKey k) =>
        RoomKeyTile(roomKey: k, busy: busy.contains(k.id), onTap: () => KeyActionsSheet.show(controller, k));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Door lock'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: 6),
          child: r.doorKeys.isEmpty
              ? _missing('No door key yet', () => RoomKeysSetupSheet.show(controller, _number))
              : Column(children: _divided([for (final k in r.doorKeys) tile(k)])),
        ),
        _heading('Students and cupboards'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: 6),
          child: r.students.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    controller.studentsUnavailable.value
                        ? 'The student list could not be loaded. Pull down to try again.'
                        : 'No student lives in this room.',
                    style: AppTextStyles.bodySm,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _divided([
                    for (final s in r.students)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s.name, style: AppTextStyles.title.copyWith(color: AppColors.textSecondary)),
                            if (r.cupboardOf(s) case final k?)
                              tile(k)
                            else
                              _missing('No cupboard key', () => RoomKeysSetupSheet.show(controller, _number)),
                          ],
                        ),
                      ),
                  ]),
                ),
        ),
        if (r.otherCupboardKeys.isNotEmpty) ...[
          _heading('Other cupboard keys'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: 6),
            child: Column(children: _divided([for (final k in r.otherCupboardKeys) tile(k)])),
          ),
        ],
      ],
    );
  }

  static List<Widget> _divided(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const Divider(height: 1, color: AppColors.borderLight),
      items[i],
    ],
  ];

  static Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: AppDimens.gapMd, bottom: AppDimens.gapSm, left: 4),
    child: Text(text.toUpperCase(), style: AppTextStyles.overline),
  );

  static Widget _missing(String text, VoidCallback onAdd) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        const Icon(Icons.key_off_rounded, size: 18, color: AppColors.warningOrange),
        const SizedBox(width: AppDimens.gapSm),
        Expanded(
          child: Text(text, style: AppTextStyles.bodySm.copyWith(color: AppColors.warningOrange)),
        ),
        TextButton(onPressed: onAdd, child: const Text('Add')),
      ],
    ),
  );
}
