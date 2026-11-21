import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/room_keys/room_key_models.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/room_keys/room_keys_repository.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../phonebook/services/phonebook_database_service.dart';

/// A room on the key register: the students who live there and its keys.
class KeyRoom {
  final String number;

  /// Current residents, each with a numeric `students.id`.
  final List<PickableStudent> students;
  final List<RoomKey> keys;

  const KeyRoom({required this.number, required this.students, required this.keys});

  List<RoomKey> get doorKeys => keys.where((k) => k.type == KeyType.door).toList();
  List<RoomKey> get cupboardKeys => keys.where((k) => k.type == KeyType.cupboard).toList();

  /// The cupboard key [student] holds in this room.
  RoomKey? cupboardOf(PickableStudent student) {
    for (final k in cupboardKeys) {
      if (k.status == KeyStatus.assigned && k.studentId == student.id) return k;
    }
    return null;
  }

  /// The door key [student] holds.
  RoomKey? doorKeyOf(PickableStudent student) {
    for (final k in doorKeys) {
      if (k.status == KeyStatus.assigned && k.studentId == student.id) return k;
    }
    return null;
  }

  /// Cupboard keys not held by a current resident (office, lost, or with
  /// someone who moved or left).
  List<RoomKey> get otherCupboardKeys {
    final residentIds = students.map((s) => s.id).toSet();
    return cupboardKeys.where((k) => !(k.status == KeyStatus.assigned && residentIds.contains(k.studentId))).toList();
  }

  /// The cupboard key labelled with [slot] ('A' ... 'G') in this room.
  RoomKey? cupboardForSlot(String slot) {
    for (final k in cupboardKeys) {
      if (k.cupboardSlot == slot) return k;
    }
    return null;
  }

  /// The in-office cupboard key for [slot], if any.
  RoomKey? officeCupboardForSlot(String slot) {
    for (final k in cupboardKeys) {
      if (k.status == KeyStatus.office && k.cupboardSlot == slot) return k;
    }
    return null;
  }

  RoomKey? get cupboardA => cupboardForSlot('A');
  RoomKey? get cupboardB => cupboardForSlot('B');
  RoomKey? get officeCupboardA => officeCupboardForSlot('A');
  RoomKey? get officeCupboardB => officeCupboardForSlot('B');

  /// The slots this room offers: A and B, or A to G for a common room, a room
  /// with more than two students, or one that already uses a later letter.
  List<String> get slotLetters {
    final wide = students.length > 2 ||
        RoomKeysController.floorLabelForRoom(number) == RoomKeysController.commonRoomsLabel ||
        cupboardKeys.any((k) => k.cupboardSlot != null && k.cupboardSlot != 'A' && k.cupboardSlot != 'B');
    return wide ? cupboardSlotLetters : const ['A', 'B'];
  }

  /// The cupboard slot expected for [student]: the one they hold, else the
  /// letter for their place in the room (A, B, C ...). Letters are handed out
  /// across the whole room in order, skipping those already held, so no two
  /// students are expected to take the same one.
  String expectedCupboardSlot(PickableStudent student) {
    final slots = slotLetters;
    final used = {
      for (final k in cupboardKeys)
        if (k.status == KeyStatus.assigned && k.cupboardSlot != null) k.cupboardSlot!,
    };
    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      final String slot;
      final own = cupboardOf(s)?.cupboardSlot;
      if (own != null) {
        slot = own;
      } else {
        final preferred = slots[i % slots.length];
        slot = used.contains(preferred) ? slots.firstWhere((l) => !used.contains(l), orElse: () => preferred) : preferred;
        used.add(slot);
      }
      if (s.id == student.id) return slot;
    }
    return slots.firstWhere((l) => !used.contains(l), orElse: () => slots.first);
  }

  /// The number on this room's door keys (they share one lock).
  String? get doorNumber => doorKeys.isEmpty ? null : doorKeys.first.keyNumber;

  bool get hasDoorKey => doorKeys.any((k) => k.status != KeyStatus.lost);

  List<PickableStudent> get studentsWithoutCupboard => students.where((s) => cupboardOf(s) == null).toList();

  /// No usable door key, or a resident without a cupboard key.
  bool get missingKeys => !hasDoorKey || studentsWithoutCupboard.isNotEmpty;

  int get attentionCount => keys.where((k) => k.needsAttention).length;
}

enum RoomFilter { all, missing, attention }

/// Operator → Room Keys: every room's door and cupboard keys, by number, and
/// who has them. Students come from [StudentPickerSource] (numeric ids only,
/// never the phonebook cache).
class RoomKeysController extends GetxController with LoadStateMixin {
  RoomKeysController({
    RoomKeysRepository? repository,
    StudentPickerSource? students,
    Future<Map<String, String>> Function()? roomGroupLoader,
  }) : _repo = repository ?? Get.find<RoomKeysRepository>(),
       _students = students ?? StudentPickerSource(),
       _roomGroupLoader = roomGroupLoader ?? phonebookRoomGroups;

  final RoomKeysRepository _repo;
  final StudentPickerSource _students;
  final Future<Map<String, String>> Function() _roomGroupLoader;

  final keys = <RoomKey>[].obs;
  static const roomOrderStorageKey = 'room_keys_room_order_v1';
  final roomOrder = <String>[].obs;
  Future<void> _orderWrite = Future<void>.value();

  /// Current residents (no alumni).
  final residents = <PickableStudent>[].obs;

  /// The student list could not be loaded; rooms then show their keys only.
  final studentsUnavailable = false.obs;

  final search = ''.obs;
  final searchController = TextEditingController();
  final filter = RoomFilter.all.obs;
  final selectedFloor = 'All'.obs;
  final selectedGroup = 'All'.obs;

  /// Group (Param, Pavitra, ...) of each room, from the phonebook synced on
  /// this phone. Display and filtering only; rooms with no entry have none.
  final roomGroups = <String, String>{}.obs;

  /// Keys with a change in flight.
  final busyIds = <int>{}.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void onSearchChanged(String value) => search.value = value;

  void clearSearch() {
    searchController.clear();
    search.value = '';
  }

  int get activeFilterCount {
    var count = 0;
    if (filter.value != RoomFilter.all) count++;
    if (selectedFloor.value != 'All') count++;
    if (selectedGroup.value != 'All') count++;
    return count;
  }

  void resetFilters() {
    filter.value = RoomFilter.all;
    selectedFloor.value = 'All';
    selectedGroup.value = 'All';
  }

  /// Label of the one filter that gathers every room that isn't on a normal
  /// floor (the 30, 40, 60 ... 90 numbers and anything non-numeric).
  static const commonRoomsLabel = 'Common rooms';

  /// Highest real hostel floor; room numbers above it (3001, 4005 ...) are
  /// common rooms.
  static const _topFloor = 9;

  static String floorLabelForRoom(String roomNumber) {
    final trimmed = roomNumber.trim().toUpperCase();
    final digits = RegExp(r'^\d+').stringMatch(trimmed);
    if (digits != null) {
      final n = int.tryParse(digits);
      if (n != null) {
        if (n < 100) return 'Ground';
        final floor = n ~/ 100;
        return floor <= _topFloor ? 'Floor $floor' : commonRoomsLabel;
      }
    }
    if (trimmed.startsWith('G')) return 'Ground';
    return commonRoomsLabel;
  }

  /// The group of [roomNumber], or null when unknown.
  String? groupOfRoom(String roomNumber) => roomGroups[normalizeRoom(roomNumber)];

  static const _groupOrder = ['Param', 'Pavitra', 'Pulkit', 'Paramanand'];

  /// 'All' and the groups that have rooms, in the usual wing order.
  List<String> get availableGroups {
    final found = roomGroups.values.toSet();
    final list = found.toList()
      ..sort((a, b) {
        final ia = _groupOrder.indexOf(a);
        final ib = _groupOrder.indexOf(b);
        if (ia != -1 || ib != -1) return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
        return a.compareTo(b);
      });
    return ['All', ...list];
  }

  List<String> get availableFloors {
    final found = <String>{};
    for (final r in rooms) {
      found.add(floorLabelForRoom(r.number));
    }
    final list = found.toList()
      ..sort((a, b) {
        if (a == 'Ground') return -1;
        if (b == 'Ground') return 1;
        if (a == commonRoomsLabel) return 1;
        if (b == commonRoomsLabel) return -1;
        final na = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 999;
        final nb = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 999;
        return na.compareTo(nb);
      });
    return ['All', ...list];
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
    final prefs = await SharedPreferences.getInstance();
    roomOrder.assignAll(prefs.getStringList(roomOrderStorageKey) ?? const []);
    final students = _students.load().then<List<PickableStudent>?>((s) => s).catchError((_) => null);
    final loaded = await _repo.list();
    final people = await students;
    keys.assignAll(loaded);
    studentsUnavailable.value = people == null;
    residents.assignAll(people ?? const []);
    // Groups are a nicety: without a synced phonebook the filter just hides.
    try {
      roomGroups.assignAll(await _roomGroupLoader());
    } catch (_) {
      roomGroups.clear();
    }
  }, showLoading: showLoading);

  // ------------------------------------------------------------------ rooms

  /// Every room with a resident or a key, in room order.
  List<KeyRoom> get rooms {
    final byRoom = <String, List<PickableStudent>>{};
    for (final s in residents) {
      final r = normalizeRoom(s.room);
      if (r.isEmpty || s.isAlumni) continue;
      byRoom.putIfAbsent(r, () => []).add(s);
    }
    final keysByRoom = <String, List<RoomKey>>{};
    for (final k in keys) {
      keysByRoom.putIfAbsent(k.roomNumber, () => []).add(k);
    }
    final numbers = {...byRoom.keys, ...keysByRoom.keys}.toList()..sort(compareRooms);
    final savedPositions = {for (var i = 0; i < roomOrder.length; i++) roomOrder[i]: i};
    numbers.sort((a, b) {
      final aPosition = savedPositions[a];
      final bPosition = savedPositions[b];
      if (aPosition == null && bPosition == null) return compareRooms(a, b);
      if (aPosition == null) return 1;
      if (bPosition == null) return -1;
      return aPosition.compareTo(bPosition);
    });
    return [
      for (final n in numbers)
        KeyRoom(number: n, students: byRoom[n] ?? const [], keys: [...?keysByRoom[n]]..sort(_keyOrder)),
    ];
  }

  KeyRoom room(String number) {
    final n = normalizeRoom(number);
    return rooms.firstWhere(
      (r) => r.number == n,
      orElse: () => KeyRoom(number: n, students: const [], keys: const []),
    );
  }

  /// Rooms for the current filter and search (room, key number or name).
  List<KeyRoom> get visibleRooms {
    final q = search.value.trim().toLowerCase();
    final floor = selectedFloor.value;
    final group = selectedGroup.value;
    return rooms.where((r) {
      if (floor != 'All' && floorLabelForRoom(r.number) != floor) {
        return false;
      }
      if (group != 'All' && groupOfRoom(r.number) != group) return false;
      switch (filter.value) {
        case RoomFilter.missing:
          if (!r.missingKeys) return false;
        case RoomFilter.attention:
          if (r.attentionCount == 0) return false;
        case RoomFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      if (r.number.toLowerCase().contains(q)) return true;
      if (r.keys.any((k) => k.keyNumber.toLowerCase().contains(q) || (k.studentName ?? '').toLowerCase().contains(q))) {
        return true;
      }
      return r.students.any((s) => s.name.toLowerCase().contains(q));
    }).toList();
  }

  /// Moves a visible room while keeping filtered-out rooms in their slots.
  /// The register order is stored locally because `/room-keys` has no order API.
  Future<void> reorderVisibleRooms(int oldIndex, int newIndex) async {
    final visible = visibleRooms.map((r) => r.number).toList();
    if (oldIndex < 0 || oldIndex >= visible.length || newIndex < 0 || newIndex > visible.length) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;
    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);
    final visibleSet = visible.toSet();
    final reordered = visible.iterator;
    final all = [for (final room in rooms) room.number];
    final next = [
      for (final room in all)
        if (visibleSet.contains(room)) (reordered..moveNext()).current else room,
    ];
    final before = roomOrder.toList();
    roomOrder.assignAll(next);
    final snapshot = List<String>.of(next);
    try {
      _orderWrite = _orderWrite.catchError((_) {}).then((_) async {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setStringList(roomOrderStorageKey, snapshot)) {
          throw StateError('Could not save room order');
        }
      });
      await _orderWrite;
    } catch (_) {
      if (roomOrder.length == snapshot.length &&
          List.generate(snapshot.length, (i) => roomOrder[i] == snapshot[i]).every((same) => same)) {
        roomOrder.assignAll(before);
      }
      AppSnackbar.error('Order Not Saved', 'Could not save the room order. Please try again.');
    }
  }

  int roomCount(RoomFilter f) => switch (f) {
    RoomFilter.all => rooms.length,
    RoomFilter.missing => rooms.where((r) => r.missingKeys).length,
    RoomFilter.attention => rooms.where((r) => r.attentionCount > 0).length,
  };

  int keyCount(KeyStatus status) => keys.where((k) => k.status == status).length;

  /// Another key with the same type and number (case-insensitive), for a
  /// warning: cupboard numbers are unique, door copies share their room's.
  RoomKey? duplicateOf(KeyType type, String number, {required String room}) {
    final n = number.trim().toLowerCase();
    if (n.isEmpty) return null;
    final r = normalizeRoom(room);
    for (final k in keys) {
      if (k.type != type || k.keyNumber.trim().toLowerCase() != n) continue;
      if (type == KeyType.door && k.roomNumber == r) continue;
      return k;
    }
    return null;
  }

  // ---------------------------------------------------------------- changes

  /// Adds a room's keys in one request. True when saved.
  Future<bool> addKeys(String roomNumber, List<NewRoomKey> newKeys) async {
    if (newKeys.isEmpty || isSaving.value) return false;
    isSaving.value = true;
    try {
      final saved = await _repo.addMany(roomNumber, newKeys);
      keys.addAll(saved);
      AppSnackbar.success(
        'Keys Saved',
        '${saved.length} ${saved.length == 1 ? 'key' : 'keys'} added to room ${normalizeRoom(roomNumber)}.',
      );
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Not Saved', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Not Saved', 'Something went wrong, try again.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Saves only [fields] (partial update). True when saved.
  Future<bool> updateKey(RoomKey key, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return true;
    if (!busyIds.add(key.id)) return false;
    try {
      _replace(await _repo.update(key.id, fields));
      AppSnackbar.success('Key Updated', '${key.title} was updated.');
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Not Saved', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Not Saved', 'Something went wrong, try again.');
      return false;
    } finally {
      busyIds.remove(key.id);
    }
  }

  /// Gives [key] to [student], returns it, or marks it lost / found. Shown at
  /// once and rolled back if the server refuses. True when saved.
  Future<bool> act(RoomKey key, KeyAction action, {PickableStudent? student, String? note}) async {
    if (action == KeyAction.assign && student == null) return false;
    if (!busyIds.add(key.id)) return false;
    final before = _current(key);
    _replace(
      before.afterAction(action, studentId: student?.id, studentName: student?.name, studentRoom: student?.room),
    );
    try {
      _replace(await _repo.act(key.id, action, studentId: student?.id, note: note));
      AppSnackbar.success('Key Updated', _actionMessage(key, action, student));
      return true;
    } on ApiException catch (e) {
      _replace(before);
      AppSnackbar.error('Not Saved', e.message);
      return false;
    } catch (_) {
      _replace(before);
      AppSnackbar.error('Not Saved', 'Something went wrong, try again.');
      return false;
    } finally {
      busyIds.remove(key.id);
    }
  }

  /// Removes [key]. True when removed.
  Future<bool> deleteKey(RoomKey key) async {
    if (!busyIds.add(key.id)) return false;
    try {
      await _repo.delete(key.id);
      keys.removeWhere((k) => k.id == key.id);
      AppSnackbar.success('Key Removed', '${key.title} was removed from room ${key.roomNumber}.');
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Not Removed', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Not Removed', 'Something went wrong, try again.');
      return false;
    } finally {
      busyIds.remove(key.id);
    }
  }

  Future<List<RoomKeyLog>> history(RoomKey key) => _repo.history(key.id);

  RoomKey _current(RoomKey key) => keys.firstWhere((k) => k.id == key.id, orElse: () => key);

  void _replace(RoomKey updated) {
    final i = keys.indexWhere((k) => k.id == updated.id);
    if (i != -1) keys[i] = updated;
  }

  static String _actionMessage(RoomKey key, KeyAction action, PickableStudent? student) => switch (action) {
    KeyAction.assign => '${key.title} given to ${student?.name ?? 'the student'}.',
    KeyAction.returnToOffice => '${key.title} is back in the office.',
    KeyAction.lost => '${key.title} marked lost.',
    KeyAction.found => '${key.title} found and back in the office.',
  };

  /// Door keys first, then cupboards, each by number.
  static int _keyOrder(RoomKey a, RoomKey b) {
    if (a.type != b.type) return a.type == KeyType.door ? -1 : 1;
    return compareRooms(a.keyNumber, b.keyNumber);
  }
}

/// Natural order: "2" < "10" < "10A" < "B-1".
int compareRooms(String a, String b) {
  final na = int.tryParse(RegExp(r'^\d+').stringMatch(a) ?? '');
  final nb = int.tryParse(RegExp(r'^\d+').stringMatch(b) ?? '');
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  if (na != null && nb == null) return -1;
  if (na == null && nb != null) return 1;
  return a.compareTo(b);
}

/// Group of each room from the phonebook synced on this phone: the group most
/// of the room's current residents belong to. Keyed by room number only; it
/// never identifies a student.
Future<Map<String, String>> phonebookRoomGroups() async {
  final students = await PhonebookDatabaseService.instance.searchStudents();
  final counts = <String, Map<String, int>>{};
  for (final s in students) {
    final group = (s.groupName ?? '').trim();
    final room = normalizeRoom(s.room ?? '');
    if (s.isAlumni || group.isEmpty || room.isEmpty) continue;
    final byGroup = counts.putIfAbsent(room, () => {});
    byGroup[group] = (byGroup[group] ?? 0) + 1;
  }
  return {
    for (final e in counts.entries)
      e.key: (e.value.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key,
  };
}
