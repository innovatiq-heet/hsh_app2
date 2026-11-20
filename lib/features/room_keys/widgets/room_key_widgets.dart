import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/room_keys/room_key_models.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/room_keys_controller.dart';

extension KeyStatusLook on KeyStatus {
  Color get color => switch (this) {
    KeyStatus.assigned => AppColors.successGreen,
    KeyStatus.office => AppColors.primary,
    KeyStatus.lost => AppColors.cancelledRed,
  };
}

extension KeyTypeLook on KeyType {
  IconData get icon => switch (this) {
    KeyType.door => Icons.door_front_door_rounded,
    KeyType.cupboard => Icons.inventory_2_rounded,
  };
}

/// Who has [k], in a few words.
String keyHolderLine(RoomKey k) => switch (k.status) {
  KeyStatus.assigned => 'With ${k.studentName ?? 'a student'}',
  KeyStatus.office => 'Kept in the office',
  KeyStatus.lost => k.studentName == null ? 'Lost' : 'Lost by ${k.studentName}',
};

/// Why [k] needs the office's attention, or null.
String? keyWarning(RoomKey k) {
  if (!k.studentMovedOrLeft) return null;
  final who = k.studentName ?? 'The student';
  return k.studentActive
      ? '$who now lives in room ${k.studentRoom}. Collect this key.'
      : '$who has left the hostel. Collect this key.';
}

/// Closes a dialog or sheet with [result]. `Get.back()` would close an open
/// snackbar instead (GetX 4), so pop the navigator of [context].
void _close(BuildContext context, [Object? result]) => Navigator.of(context).pop(result);

Future<bool> _confirm({
  required String title,
  required String message,
  required String action,
  bool danger = false,
}) async {
  final ok = await Get.dialog<bool>(
    Builder(
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => _close(ctx, false), child: const Text('Cancel')),
          AppButton(
            label: action,
            expand: false,
            variant: danger ? AppButtonVariant.danger : AppButtonVariant.primary,
            onPressed: () => _close(ctx, true),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// One key: type icon, number and name, who has it, and any warning.
class RoomKeyTile extends StatelessWidget {
  final RoomKey roomKey;
  final VoidCallback? onTap;
  final bool busy;

  const RoomKeyTile({super.key, required this.roomKey, this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final k = roomKey;
    final warning = keyWarning(k);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: k.status.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(k.type.icon, size: 20, color: k.status.color),
            ),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (k.cupboardSlot != null)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            k.title,
                            style: AppTextStyles.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: k.cupboardSlot == 'A' ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: k.cupboardSlot == 'A' ? const Color(0xFF0284C7) : const Color(0xFF9333EA),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'CUPBOARD ${k.cupboardSlot}',
                            style: TextStyle(
                              color: k.cupboardSlot == 'A' ? const Color(0xFF0284C7) : const Color(0xFF9333EA),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      k.displayTitle,
                      style: AppTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Text(keyHolderLine(k), style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (warning != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      warning,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warningOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.gapSm),
            if (busy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              StatusBadge(label: k.status.label, color: k.status.color),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- set up

Widget _slotChoiceChip({
  required String label,
  required bool selected,
  required Color color,
  required VoidCallback onTap,
}) => InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(8),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: selected ? color : const Color(0xFFCBD5E1),
        width: selected ? 1.5 : 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: selected ? color : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : const Color(0xFF475569),
          ),
        ),
      ],
    ),
  ),
);

/// Adds a room's keys in one go: the door key number with a copy per chosen
/// student and spares for the office, a cupboard key number per student, and
/// spare cupboard keys. Keys a student already has are shown, not asked for.
class RoomKeysSetupSheet extends StatefulWidget {
  final RoomKeysController controller;
  final String room;

  const RoomKeysSetupSheet({super.key, required this.controller, required this.room});

  static Future<void> show(RoomKeysController controller, String room) => Get.bottomSheet(
    RoomKeysSetupSheet(controller: controller, room: room),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );

  @override
  State<RoomKeysSetupSheet> createState() => _RoomKeysSetupSheetState();
}

class _RoomKeysSetupSheetState extends State<RoomKeysSetupSheet> {
  late final KeyRoom _room = widget.controller.room(widget.room);
  late final _door = TextEditingController(text: _room.doorNumber ?? '');
  final _cupboards = <int, TextEditingController>{};
  final _studentCupboardSlots = <int, String>{};
  final _doorCopyFor = <int>{};
  late int _spareDoorKeys = _room.doorKeys.isEmpty ? 1 : 0;
  final _spareCupboards = <TextEditingController>[];
  final _spareCupboardSlots = <String>[];
  String? _error;

  bool get _doorFixed => _room.doorKeys.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final takenSlots = _room.cupboardKeys
        .map((k) => k.cupboardSlot)
        .whereType<String>()
        .toSet();

    var nextSlot = takenSlots.contains('A') ? 'B' : 'A';
    for (final s in _room.students) {
      if (_room.cupboardOf(s) == null) {
        _cupboards[s.id] = TextEditingController();
        _studentCupboardSlots[s.id] = nextSlot;
        if (nextSlot == 'A' && !takenSlots.contains('B')) {
          nextSlot = 'B';
        } else if (nextSlot == 'B' && !takenSlots.contains('A')) {
          nextSlot = 'A';
        }
      }
    }
  }

  @override
  void dispose() {
    _door.dispose();
    for (final c in [..._cupboards.values, ..._spareCupboards]) {
      c.dispose();
    }
    super.dispose();
  }

  List<NewRoomKey>? _collect() {
    final door = _door.text.trim();
    final out = <NewRoomKey>[];
    final doorKeys = _doorCopyFor.length + _spareDoorKeys;
    if (doorKeys > 0) {
      if (door.isEmpty) {
        setState(() => _error = 'Type the door key number.');
        return null;
      }
      for (final id in _doorCopyFor) {
        out.add(NewRoomKey(type: KeyType.door, keyNumber: door, studentId: id));
      }
      for (var i = 0; i < _spareDoorKeys; i++) {
        out.add(NewRoomKey(type: KeyType.door, keyNumber: door));
      }
    }
    final typed = <String>{};
    void cupboard(String number, int? studentId, String? slot) {
      if (number.isEmpty) return;
      if (!typed.add(number.toLowerCase())) {
        _error = 'Cupboard key $number is typed twice.';
        return;
      }
      final label = slot == null || slot == 'Other' ? null : 'Cupboard $slot';
      out.add(NewRoomKey(type: KeyType.cupboard, keyNumber: number, label: label, studentId: studentId));
    }

    _error = null;
    for (final e in _cupboards.entries) {
      cupboard(e.value.text.trim(), e.key, _studentCupboardSlots[e.key]);
    }
    for (var i = 0; i < _spareCupboards.length; i++) {
      cupboard(_spareCupboards[i].text.trim(), null, _spareCupboardSlots[i]);
    }
    if (_error != null) {
      setState(() {});
      return null;
    }
    if (out.isEmpty) {
      setState(() => _error = 'Type at least one key number.');
      return null;
    }
    return out;
  }

  /// Numbers already used elsewhere, for a warning.
  List<String> _duplicates(List<NewRoomKey> keys) {
    final seen = <String>{};
    final out = <String>[];
    for (final k in keys) {
      final other = widget.controller.duplicateOf(k.type, k.keyNumber, room: widget.room);
      if (other == null || !seen.add('${k.type.wire}:${k.keyNumber.toLowerCase()}')) continue;
      out.add('${other.title} is already in room ${other.roomNumber}');
    }
    return out;
  }

  Future<void> _save() async {
    final keys = _collect();
    if (keys == null) return;
    setState(() => _error = null);
    final dups = _duplicates(keys);
    if (dups.isNotEmpty) {
      final ok = await _confirm(
        title: 'Number already used',
        message: '${dups.join('.\n')}.\n\nSave anyway?',
        action: 'Save anyway',
      );
      if (!ok) return;
    }
    final saved = await widget.controller.addKeys(widget.room, keys);
    if (saved && mounted) _close(context);
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return SheetScaffold(
      title: 'Keys for room ${widget.room}',
      subtitle: 'Type the number stamped on each key. Leave a box empty to skip it.',
      children: [
        _heading('Door lock'),
        AppTextField(
          controller: _door,
          label: 'Door key number',
          hint: 'e.g. 204',
          prefixIcon: Icons.door_front_door_outlined,
          readOnly: _doorFixed,
        ),
        if (_doorFixed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'This room has ${room.doorKeys.length} door ${room.doorKeys.length == 1 ? 'key' : 'keys'}; new copies share the number.',
              style: AppTextStyles.caption,
            ),
          ),
        const SizedBox(height: AppDimens.gapSm),
        Row(
          children: [
            Expanded(child: Text('Spare door keys kept in the office', style: AppTextStyles.bodyMd)),
            IconButton(
              tooltip: 'One less',
              onPressed: _spareDoorKeys == 0 ? null : () => setState(() => _spareDoorKeys--),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text('$_spareDoorKeys', style: AppTextStyles.title),
            IconButton(
              tooltip: 'One more',
              onPressed: _spareDoorKeys >= 10 ? null : () => setState(() => _spareDoorKeys++),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        if (room.students.isNotEmpty) ...[
          _heading('Students in this room'),
          for (final s in room.students) _studentRow(room, s),
        ],
        _heading('Spare cupboard keys (office)'),
        for (var i = 0; i < _spareCupboards.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Key ${i + 1}:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    _slotChoiceChip(
                      label: 'Cupboard A',
                      selected: _spareCupboardSlots[i] == 'A',
                      color: const Color(0xFF0284C7),
                      onTap: () => setState(() => _spareCupboardSlots[i] = 'A'),
                    ),
                    const SizedBox(width: 6),
                    _slotChoiceChip(
                      label: 'Cupboard B',
                      selected: _spareCupboardSlots[i] == 'B',
                      color: const Color(0xFF9333EA),
                      onTap: () => setState(() => _spareCupboardSlots[i] = 'B'),
                    ),
                    const SizedBox(width: 6),
                    _slotChoiceChip(
                      label: 'Other',
                      selected: _spareCupboardSlots[i] == 'Other',
                      color: const Color(0xFF475569),
                      onTap: () => setState(() => _spareCupboardSlots[i] = 'Other'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _spareCupboards[i],
                  label: _spareCupboardSlots[i] == 'Other'
                      ? 'Cupboard key number'
                      : 'Cupboard ${_spareCupboardSlots[i]} key number',
                  hint: 'e.g. 101',
                  prefixIcon: Icons.inventory_2_outlined,
                  suffix: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _spareCupboards.removeAt(i).dispose();
                      _spareCupboardSlots.removeAt(i);
                    }),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _spareCupboards.add(TextEditingController());
              final nextSpare = _spareCupboardSlots.contains('A') ? 'B' : 'A';
              _spareCupboardSlots.add(nextSpare);
            }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a spare cupboard key'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppDimens.gapSm),
          Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.cancelledRed)),
        ],
        const SizedBox(height: AppDimens.gapLg),
        Obx(
          () => AppButton(
            label: 'Save keys',
            icon: Icons.key_rounded,
            isLoading: widget.controller.isSaving.value,
            onPressed: _save,
          ),
        ),
      ],
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: AppDimens.gapLg, bottom: AppDimens.gapSm),
    child: Text(text.toUpperCase(), style: AppTextStyles.overline),
  );

  Widget _studentRow(KeyRoom room, PickableStudent s) {
    final cupboard = room.cupboardOf(s);
    final door = room.doorKeyOf(s);
    final selectedSlot = _studentCupboardSlots[s.id] ?? 'A';
    // A Material (not a coloured Container) so the checkbox row's ripple shows.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.name, style: AppTextStyles.title),
              const SizedBox(height: AppDimens.gapSm),
              if (cupboard != null)
                Text('Has ${cupboard.displayTitle}', style: AppTextStyles.bodySm)
              else ...[
                Row(
                  children: [
                    Text('Cupboard:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    _slotChoiceChip(
                      label: 'Cupboard A',
                      selected: selectedSlot == 'A',
                      color: const Color(0xFF0284C7),
                      onTap: () => setState(() => _studentCupboardSlots[s.id] = 'A'),
                    ),
                    const SizedBox(width: 6),
                    _slotChoiceChip(
                      label: 'Cupboard B',
                      selected: selectedSlot == 'B',
                      color: const Color(0xFF9333EA),
                      onTap: () => setState(() => _studentCupboardSlots[s.id] = 'B'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _cupboards[s.id],
                  label: 'Cupboard key number',
                  hint: 'Cupboard $selectedSlot (e.g. 101)',
                  prefixIcon: Icons.inventory_2_outlined,
                ),
              ],
              if (door != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Has ${door.displayTitle}', style: AppTextStyles.bodySm),
                )
              else
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _doorCopyFor.contains(s.id),
                  title: const Text('Give a door key copy'),
                  onChanged: (v) => setState(() => v == true ? _doorCopyFor.add(s.id) : _doorCopyFor.remove(s.id)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- actions

/// What can be done with one key.
class KeyActionsSheet extends StatelessWidget {
  final RoomKeysController controller;
  final RoomKey roomKey;

  const KeyActionsSheet({super.key, required this.controller, required this.roomKey});

  static Future<void> show(RoomKeysController controller, RoomKey key) => Get.bottomSheet(
    KeyActionsSheet(controller: controller, roomKey: key),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );

  @override
  Widget build(BuildContext context) {
    final k = roomKey;
    final warning = keyWarning(k);
    void closeThen(Future<void> Function() next) {
      _close(context);
      next();
    }

    Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(label, style: AppTextStyles.bodyLg.copyWith(color: color ?? AppColors.textPrimary)),
      onTap: onTap,
    );

    return SheetScaffold(
      title: k.displayTitle,
      subtitle: [
        'Room ${k.roomNumber}',
        if (k.label != null && k.cupboardSlot == null) k.label!,
        if (k.updatedAt != null) 'Updated ${DateFormatting.dateTime(k.updatedAt!)}',
      ].join(' · '),
      children: [
        Row(
          children: [
            StatusBadge(label: k.status.label, color: k.status.color),
            const SizedBox(width: AppDimens.gapSm),
            Expanded(child: Text(keyHolderLine(k), style: AppTextStyles.bodyMd)),
          ],
        ),
        if (warning != null) ...[
          const SizedBox(height: AppDimens.gapSm),
          Text(
            warning,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.warningOrange, fontWeight: FontWeight.w700),
          ),
        ],
        if (k.notes != null) ...[const SizedBox(height: AppDimens.gapSm), Text(k.notes!, style: AppTextStyles.bodySm)],
        const SizedBox(height: AppDimens.gapMd),
        const Divider(height: 1, color: AppColors.borderLight),
        if (k.status == KeyStatus.assigned) ...[
          action(
            Icons.swap_horiz_rounded,
            'Give to another student',
            () => closeThen(() => AssignKeySheet.show(controller, k)),
          ),
          action(
            Icons.move_to_inbox_rounded,
            'Returned to office',
            () => closeThen(() => controller.act(k, KeyAction.returnToOffice)),
          ),
        ] else
          action(
            Icons.person_add_alt_1_rounded,
            'Give to a student',
            () => closeThen(() => AssignKeySheet.show(controller, k)),
          ),
        if (k.status == KeyStatus.lost)
          action(
            Icons.manage_search_rounded,
            'Found, back in office',
            () => closeThen(() => controller.act(k, KeyAction.found)),
          )
        else
          action(
            Icons.report_gmailerrorred_rounded,
            'Mark lost',
            () => closeThen(() async {
              final ok = await _confirm(
                title: 'Mark ${k.title} lost?',
                message: k.studentName == null
                    ? 'The key will show as lost until it is found.'
                    : 'The key will show as lost by ${k.studentName} until it is found.',
                action: 'Mark lost',
                danger: true,
              );
              if (ok) await controller.act(k, KeyAction.lost);
            }),
            color: AppColors.cancelledRed,
          ),
        action(Icons.edit_rounded, 'Edit number or name', () => closeThen(() => KeyEditSheet.show(controller, k))),
        action(Icons.history_rounded, 'History', () => closeThen(() => KeyHistorySheet.show(controller, k))),
        action(
          Icons.delete_outline_rounded,
          'Remove key',
          () => closeThen(() async {
            final ok = await _confirm(
              title: 'Remove ${k.title}?',
              message: 'Remove it from room ${k.roomNumber}, e.g. when the lock is changed. Its history is kept.',
              action: 'Remove',
              danger: true,
            );
            if (ok) await controller.deleteKey(k);
          }),
          color: AppColors.cancelledRed,
        ),
      ],
    );
  }
}

/// Picks the student to give a key to: the room's students first, anyone
/// else by search. Students are numeric `students.id` only.
class AssignKeySheet extends StatefulWidget {
  final RoomKeysController controller;
  final RoomKey roomKey;

  const AssignKeySheet({super.key, required this.controller, required this.roomKey});

  static Future<void> show(RoomKeysController controller, RoomKey key) => Get.bottomSheet(
    AssignKeySheet(controller: controller, roomKey: key),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );

  @override
  State<AssignKeySheet> createState() => _AssignKeySheetState();
}

class _AssignKeySheetState extends State<AssignKeySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final k = widget.roomKey;
    final current = k.status == KeyStatus.assigned ? k.studentId : null;
    final roommates = widget.controller.room(k.roomNumber).students.where((s) => s.id != current).toList();
    final q = _query.trim().toLowerCase();
    final others = q.isEmpty
        ? const <PickableStudent>[]
        : widget.controller.residents
              .where((s) => s.id != current && normalizeRoom(s.room) != k.roomNumber)
              .where((s) => s.name.toLowerCase().contains(q) || s.room.toLowerCase().contains(q))
              .take(30)
              .toList();

    Widget tile(PickableStudent s) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Text(
          s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
          style: AppTextStyles.title.copyWith(color: AppColors.primary),
        ),
      ),
      title: Text(s.name, style: AppTextStyles.title),
      subtitle: Text('Room ${s.room}', style: AppTextStyles.bodySm),
      onTap: () {
        _close(context);
        widget.controller.act(k, KeyAction.assign, student: s);
      },
    );

    return SheetScaffold(
      title: 'Give ${k.displayTitle} to',
      subtitle: 'Room ${k.roomNumber}',
      children: [
        if (roommates.isNotEmpty) ...[
          Text('IN THIS ROOM', style: AppTextStyles.overline),
          for (final s in roommates) tile(s),
          const SizedBox(height: AppDimens.gapMd),
        ],
        AppTextField(
          label: 'Another student',
          hint: 'Search by name or room',
          prefixIcon: Icons.search_rounded,
          onChanged: (v) => setState(() => _query = v),
        ),
        for (final s in others) tile(s),
        if (q.isNotEmpty && others.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.gapMd),
            child: Text('No student found.', style: AppTextStyles.bodySm),
          ),
        if (roommates.isEmpty && q.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.gapMd),
            child: Text('Nobody else lives in this room. Search for a student.', style: AppTextStyles.bodySm),
          ),
      ],
    );
  }
}

/// Changes a key's type, number, name or notes; only changed fields are sent.
class KeyEditSheet extends StatefulWidget {
  final RoomKeysController controller;
  final RoomKey roomKey;

  const KeyEditSheet({super.key, required this.controller, required this.roomKey});

  static Future<void> show(RoomKeysController controller, RoomKey key) => Get.bottomSheet(
    KeyEditSheet(controller: controller, roomKey: key),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );

  @override
  State<KeyEditSheet> createState() => _KeyEditSheetState();
}

class _KeyEditSheetState extends State<KeyEditSheet> {
  late KeyType _type = widget.roomKey.type;
  late final _number = TextEditingController(text: widget.roomKey.keyNumber);
  late final _label = TextEditingController(text: widget.roomKey.label ?? '');
  late final _notes = TextEditingController(text: widget.roomKey.notes ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  Map<String, dynamic> _changes() {
    final k = widget.roomKey;
    final label = _label.text.trim();
    final notes = _notes.text.trim();
    return {
      if (_type != k.type) 'key_type': _type.wire,
      if (_number.text.trim() != k.keyNumber) 'key_number': _number.text.trim(),
      if (label != (k.label ?? '')) 'label': label.isEmpty ? null : label,
      if (notes != (k.notes ?? '')) 'notes': notes.isEmpty ? null : notes,
    };
  }

  Future<void> _save() async {
    if (_number.text.trim().isEmpty) {
      setState(() => _error = 'Type the key number.');
      return;
    }
    final changes = _changes();
    if (changes.isEmpty) {
      _close(context);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final ok = await widget.controller.updateKey(widget.roomKey, changes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _close(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Edit ${widget.roomKey.displayTitle}',
      subtitle: 'Room ${widget.roomKey.roomNumber}',
      children: [
        SegmentedButton<KeyType>(
          segments: [for (final t in KeyType.values) ButtonSegment(value: t, label: Text(t.label), icon: Icon(t.icon))],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: AppDimens.gapMd),
        AppTextField(controller: _number, label: 'Key number', prefixIcon: Icons.tag_rounded),
        const SizedBox(height: AppDimens.gapMd),
        AppTextField(controller: _label, label: 'Name (optional)', hint: 'e.g. Main door, Cupboard A'),
        if (_type == KeyType.cupboard) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Quick label:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _slotChoiceChip(
                label: 'Cupboard A',
                selected: _label.text.trim().toUpperCase() == 'CUPBOARD A',
                color: const Color(0xFF0284C7),
                onTap: () => setState(() => _label.text = 'Cupboard A'),
              ),
              const SizedBox(width: 6),
              _slotChoiceChip(
                label: 'Cupboard B',
                selected: _label.text.trim().toUpperCase() == 'CUPBOARD B',
                color: const Color(0xFF9333EA),
                onTap: () => setState(() => _label.text = 'Cupboard B'),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppDimens.gapMd),
        AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 3),
        if (_error != null) ...[
          const SizedBox(height: AppDimens.gapSm),
          Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.cancelledRed)),
        ],
        const SizedBox(height: AppDimens.gapLg),
        AppButton(label: 'Save', icon: Icons.check_rounded, isLoading: _saving, onPressed: _save),
      ],
    );
  }
}

/// Everything that happened to one key, newest first.
class KeyHistorySheet extends StatelessWidget {
  final RoomKeysController controller;
  final RoomKey roomKey;

  const KeyHistorySheet({super.key, required this.controller, required this.roomKey});

  static Future<void> show(RoomKeysController controller, RoomKey key) => Get.bottomSheet(
    KeyHistorySheet(controller: controller, roomKey: key),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'History of ${roomKey.displayTitle}',
      subtitle: 'Room ${roomKey.roomNumber}',
      children: [
        FutureBuilder<List<RoomKeyLog>>(
          future: controller.history(roomKey),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppDimens.gapXl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Text(
                'Could not load the history. Try again.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.cancelledRed),
              );
            }
            final logs = snap.data ?? const [];
            if (logs.isEmpty) return Text('Nothing recorded yet.', style: AppTextStyles.bodySm);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final log in logs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.summary, style: AppTextStyles.title),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (log.at != null) DateFormatting.dateTime(log.at!),
                            if (log.byName != null) 'by ${log.byName}',
                          ].join(' · '),
                          style: AppTextStyles.caption,
                        ),
                        if (log.note != null) ...[
                          const SizedBox(height: 2),
                          Text(log.note!, style: AppTextStyles.bodySm),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
