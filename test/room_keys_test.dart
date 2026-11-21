import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/constants/app_routes.dart';
import 'package:hsh_app2/core/models/room_keys/room_key_models.dart';
import 'package:hsh_app2/core/models/students/pickable_student.dart';
import 'package:hsh_app2/core/network/repository/room_keys/room_keys_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/room_keys/bindings/room_keys_binding.dart';
import 'package:hsh_app2/features/room_keys/controllers/room_keys_controller.dart';
import 'package:hsh_app2/features/room_keys/views/room_keys_room_screen.dart';
import 'package:hsh_app2/features/room_keys/views/room_keys_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/test_fonts.dart';

/// Operator → Room Keys against `/room-keys`, with HTTP faked offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> keyJson(
    int id,
    String room,
    String type,
    String number, {
    String status = 'office',
    Object? studentId,
    String? studentName,
    String? studentRoom,
    Object studentActive = true,
  }) => {
    'id': id,
    'room_number': room,
    'key_type': type,
    'key_number': number,
    'status': status,
    'student_id': studentId,
    'student_name': studentName,
    'student_room': studentRoom,
    'student_active': studentActive,
    'updated_at': '2026-11-16T05:30:00Z',
  };

  final students = [
    {'id': 11, 'name': 'Asha Patel', 'room_number': '204'},
    {'id': 12, 'name': 'Bhavin Shah', 'room_number': '204'},
    {'id': 13, 'name': 'Chirag Joshi', 'room_number': '305'},
    // A bank code is never an id: this row must not become a student.
    {'id': '0768', 'name': 'Bank Code', 'room_number': '204'},
  ];

  List<Map<String, dynamic>> hostelKeys() => [
    keyJson(1, '204', 'door', '204'),
    keyJson(
      2,
      '204',
      'cupboard',
      '1123',
      status: 'assigned',
      studentId: 11,
      studentName: 'Asha Patel',
      studentRoom: '204',
    ),
    // Given to a student who has since left the hostel.
    keyJson(
      3,
      '305',
      'cupboard',
      '2001',
      status: 'assigned',
      studentId: 99,
      studentName: 'Old Student',
      studentRoom: '',
      studentActive: 0,
    ),
    // A room nobody lives in, with a lost key.
    keyJson(4, '410', 'cupboard', '3001', status: 'lost'),
  ];

  group('RoomKey', () {
    test('reads the API row; a bank code never becomes a student id', () {
      final k = RoomKey.fromJson(keyJson(5, ' 204 ', 'cupboard', '1123', status: 'assigned', studentId: '0768'));
      expect(k.roomNumber, '204');
      expect(k.type, KeyType.cupboard);
      expect(k.status, KeyStatus.assigned);
      expect(k.studentId, isNull);
      expect(k.title, 'Cupboard 1123');
    });

    test('unknown or missing values fall back to a cupboard key in the office', () {
      final k = RoomKey.fromJson({'id': 6, 'room_number': '101', 'key_number': '9'});
      expect(k.type, KeyType.cupboard);
      expect(k.status, KeyStatus.office);
    });

    test('a key with a student who moved or left needs attention', () {
      final moved = RoomKey.fromJson(
        keyJson(7, '204', 'door', '204', status: 'assigned', studentId: 11, studentName: 'Asha', studentRoom: '305'),
      );
      final left = RoomKey.fromJson(
        keyJson(
          8,
          '204',
          'door',
          '204',
          status: 'assigned',
          studentId: 11,
          studentName: 'Asha',
          studentRoom: '204',
          studentActive: false,
        ),
      );
      final fine = RoomKey.fromJson(
        keyJson(9, '204', 'door', '204', status: 'assigned', studentId: 11, studentName: 'Asha', studentRoom: '204'),
      );
      expect(moved.needsAttention, isTrue);
      expect(left.needsAttention, isTrue);
      expect(fine.needsAttention, isFalse);
      expect(RoomKey.fromJson(keyJson(10, '204', 'door', '204', status: 'lost')).needsAttention, isTrue);
    });

    test('a new key is sent with a numeric student id, or none', () {
      expect(const NewRoomKey(type: KeyType.cupboard, keyNumber: ' 1124 ', studentId: 12).toJson(), {
        'key_type': 'cupboard',
        'key_number': '1124',
        'student_id': 12,
      });
      expect(const NewRoomKey(type: KeyType.door, keyNumber: '204', label: ' ').toJson(), {
        'key_type': 'door',
        'key_number': '204',
      });
    });

    test('recognizes Cupboard A and Cupboard B designations and formats titles', () {
      final keyA = RoomKey.fromJson({'id': 31, 'room_number': '101', 'key_type': 'cupboard', 'key_number': '501', 'label': 'Cupboard A'});
      final keyB = RoomKey.fromJson({'id': 32, 'room_number': '101', 'key_type': 'cupboard', 'key_number': '502', 'label': 'Cupboard B'});
      final keyPlain = RoomKey.fromJson({'id': 33, 'room_number': '101', 'key_type': 'cupboard', 'key_number': '503'});

      expect(keyA.cupboardSlot, 'A');
      expect(keyA.title, 'Cupboard A · Key 501');
      expect(keyA.displayTitle, 'Cupboard A · Key 501');

      expect(keyB.cupboardSlot, 'B');
      expect(keyB.title, 'Cupboard B · Key 502');
      expect(keyB.displayTitle, 'Cupboard B · Key 502');

      expect(keyPlain.cupboardSlot, isNull);
      expect(keyPlain.title, 'Cupboard 503');
      expect(keyPlain.displayTitle, 'Cupboard 503');
    });

    test('rooms sort in natural order', () {
      final rooms = ['B-1', '10', '2', '10A', '101']..sort(compareRooms);
      expect(rooms, ['2', '10', '10A', '101', 'B-1']);
    });
  });

  group('controller', () {
    late FakeApi api;

    setUp(() {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'admin-token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
      });
      Get.put(SessionStore());
      api = FakeApi()..install();
      Get.put(TagsRepository());
      Get.put(RoomKeysRepository());
      api.on('GET /students', {'success': true, 'data': students});
      api.on('GET /room-keys', {
        'success': true,
        'data': {'keys': hostelKeys()},
      });
    });

    tearDown(Get.reset);

    Future<RoomKeysController> loaded() async {
      final c = Get.put(RoomKeysController());
      await until(() => !c.isLoading.value, reason: 'room keys load');
      expect(c.hasError.value, isFalse, reason: c.errorMessage.value);
      return c;
    }

    test('groups students and keys by room', () async {
      final c = await loaded();
      expect(c.rooms.map((r) => r.number), ['204', '305', '410']);

      final r204 = c.room('204');
      expect(r204.students.map((s) => s.name), ['Asha Patel', 'Bhavin Shah']);
      expect(r204.doorNumber, '204');
      expect(r204.cupboardOf(r204.students.first)?.keyNumber, '1123');
      expect(r204.studentsWithoutCupboard.map((s) => s.name), ['Bhavin Shah']);
      expect(r204.missingKeys, isTrue);

      final r305 = c.room('305');
      expect(r305.hasDoorKey, isFalse);
      expect(r305.otherCupboardKeys.map((k) => k.keyNumber), ['2001']);
      expect(r305.attentionCount, 1);

      expect(c.room('410').students, isEmpty);
      expect(c.keyCount(KeyStatus.assigned), 2);
      expect(c.keyCount(KeyStatus.office), 1);
      expect(c.keyCount(KeyStatus.lost), 1);
    });

    test('reordered rooms persist after reloading', () async {
      final c = await loaded();
      expect(c.visibleRooms.map((r) => r.number), ['204', '305', '410']);
      await c.reorderVisibleRooms(2, 0);
      expect(c.visibleRooms.map((r) => r.number), ['410', '204', '305']);
      expect((await SharedPreferences.getInstance()).getStringList(RoomKeysController.roomOrderStorageKey),
          ['410', '204', '305']);
      await c.load();
      expect(c.visibleRooms.map((r) => r.number), ['410', '204', '305']);
    });

    test('reordering a filtered list keeps hidden rooms in place', () async {
      final c = await loaded();
      c.filter.value = RoomFilter.attention;
      expect(c.visibleRooms.map((r) => r.number), ['305', '410']);
      await c.reorderVisibleRooms(1, 0);
      expect(c.rooms.map((r) => r.number), ['204', '410', '305']);
      c.filter.value = RoomFilter.all;
      expect(c.visibleRooms.map((r) => r.number), ['204', '410', '305']);
    });

    test('filters and search by room, key number or name', () async {
      final c = await loaded();
      expect(c.roomCount(RoomFilter.missing), 3);
      expect(c.roomCount(RoomFilter.attention), 2);

      c.filter.value = RoomFilter.attention;
      expect(c.visibleRooms.map((r) => r.number), ['305', '410']);

      c.filter.value = RoomFilter.all;
      c.search.value = '1123';
      expect(c.visibleRooms.map((r) => r.number), ['204']);
      c.search.value = 'chirag';
      expect(c.visibleRooms.map((r) => r.number), ['305']);
      c.search.value = '41';
      expect(c.visibleRooms.map((r) => r.number), ['410']);
    });

    test('warns about a cupboard number used elsewhere, not about door copies of the same room', () async {
      final c = await loaded();
      expect(c.duplicateOf(KeyType.cupboard, '2001', room: '204')?.roomNumber, '305');
      expect(c.duplicateOf(KeyType.door, '204', room: '204'), isNull);
      expect(c.duplicateOf(KeyType.door, '204', room: '205')?.roomNumber, '204');
      expect(c.duplicateOf(KeyType.cupboard, '9999', room: '204'), isNull);
    });

    test('adding keys sends the room and numeric student ids in one request', () async {
      final c = await loaded();
      api.on('POST /room-keys/batch', {
        'success': true,
        'data': {
          'keys': [
            keyJson(
              20,
              '204',
              'cupboard',
              '1124',
              status: 'assigned',
              studentId: 12,
              studentName: 'Bhavin Shah',
              studentRoom: '204',
            ),
          ],
        },
      });

      final ok = await c.addKeys(' 204 ', const [NewRoomKey(type: KeyType.cupboard, keyNumber: '1124', studentId: 12)]);

      expect(ok, isTrue);
      final body = api.last('POST /room-keys/batch').data as Map;
      expect(body['room_number'], '204');
      expect(body['keys'], [
        {'key_type': 'cupboard', 'key_number': '1124', 'student_id': 12},
      ]);
      expect(c.room('204').missingKeys, isFalse);
    });

    test('giving a key to a student sends only the action and the numeric id', () async {
      final c = await loaded();
      api.on('POST /room-keys/1/action', {
        'success': true,
        'data': keyJson(
          1,
          '204',
          'door',
          '204',
          status: 'assigned',
          studentId: 12,
          studentName: 'Bhavin Shah',
          studentRoom: '204',
        ),
      });
      final bhavin = c.room('204').students.last;

      final ok = await c.act(c.keys.first, KeyAction.assign, student: bhavin);

      expect(ok, isTrue);
      expect(api.last('POST /room-keys/1/action').data, {'action': 'assign', 'student_id': 12});
      expect(c.room('204').doorKeyOf(bhavin)?.id, 1);
    });

    test('a refused change is rolled back', () async {
      final c = await loaded();
      api.on('POST /room-keys/2/action', {'success': false, 'message': 'Key not found'}, status: 404);

      final ok = await c.act(c.keys[1], KeyAction.returnToOffice);

      expect(ok, isFalse);
      expect(c.keys[1].status, KeyStatus.assigned);
      expect(c.keys[1].studentId, 11);
    });

    test('editing sends only the changed fields; removing drops the key', () async {
      final c = await loaded();
      api.on('PUT /room-keys/1', {'success': true, 'data': keyJson(1, '204', 'door', '204A')});
      api.on('DELETE /room-keys/4', {'success': true});

      expect(await c.updateKey(c.keys.first, {'key_number': '204A'}), isTrue);
      expect(api.last('PUT /room-keys/1').data, {'key_number': '204A'});
      expect(c.keys.first.keyNumber, '204A');

      expect(await c.deleteKey(c.keys.last), isTrue);
      expect(c.keys.map((k) => k.id), isNot(contains(4)));
    });

    test('the keys still show when the student list fails', () async {
      api.on('GET /students', {'success': false, 'message': 'down'}, status: 500);
      api.on('GET /screen-time/students', {'success': false, 'message': 'down'}, status: 500);
      final c = await loaded();
      expect(c.studentsUnavailable.value, isTrue);
      expect(c.keys, hasLength(4));
    });

    test('common rooms give each student their own cupboard letter, A to G', () {
      PickableStudent student(int id) => PickableStudent(id: id, name: 'Student $id', room: '3000');
      final five = [for (var i = 1; i <= 5; i++) student(i)];
      final room = KeyRoom(number: '3000', students: five, keys: const []);

      expect(room.slotLetters, cupboardSlotLetters);
      expect([for (final s in five) room.expectedCupboardSlot(s)], ['A', 'B', 'C', 'D', 'E']);

      // Student 2 already holds C: they keep it, and student 3 moves on.
      final held = RoomKey.fromJson({
        'id': 1, 'room_number': '3000', 'key_type': 'cupboard', 'key_number': '77', 'label': 'Cupboard C',
        'status': 'assigned', 'student_id': 2, 'student_name': 'Student 2', 'student_room': '3000',
      });
      final withHeld = KeyRoom(number: '3000', students: five, keys: [held]);
      expect(withHeld.expectedCupboardSlot(five[1]), 'C');
      expect(withHeld.expectedCupboardSlot(five[2]), isNot('C'));
      expect({for (final s in five) withHeld.expectedCupboardSlot(s)}.length, 5, reason: 'no letter is given twice');
    });

    test('an ordinary two-student room still uses only A and B', () {
      final two = [
        const PickableStudent(id: 1, name: 'One', room: '204'),
        const PickableStudent(id: 2, name: 'Two', room: '204'),
      ];
      final room = KeyRoom(number: '204', students: two, keys: const []);
      expect(room.slotLetters, ['A', 'B']);
      expect([for (final s in two) room.expectedCupboardSlot(s)], ['A', 'B']);
    });

    test('cupboard letters C to G are read from the label', () {
      RoomKey key(String label) => RoomKey.fromJson({
        'id': 1, 'room_number': '3000', 'key_type': 'cupboard', 'key_number': '1', 'label': label,
      });
      for (final l in ['C', 'D', 'E', 'F', 'G']) {
        expect(key('Cupboard $l').cupboardSlot, l);
        expect(key(l.toLowerCase()).cupboardSlot, l);
      }
      expect(key('Cupboard H').cupboardSlot, isNull);
      expect(key('Main cupboard').cupboardSlot, isNull);
    });

    test('rooms on unusual floors (30, 40 ... 90, non-numeric) are one common-rooms filter', () {
      String f(String room) => RoomKeysController.floorLabelForRoom(room);
      expect(f('45'), 'Ground');
      expect(f('G2'), 'Ground');
      expect(f('204'), 'Floor 2');
      expect(f('917'), 'Floor 9');
      for (final room in ['3004', '4001', '6002', '7010', '8003', '9005', 'X-1', 'Library']) {
        expect(f(room), RoomKeysController.commonRoomsLabel, reason: room);
      }
    });

    test('the group filter keeps the rooms of that group and counts as a filter', () async {
      final c = Get.put(RoomKeysController(roomGroupLoader: () async => {'204': 'Pavitra', '305': 'Param'}));
      await until(() => !c.isLoading.value, reason: 'room keys load');

      expect(c.availableGroups, ['All', 'Param', 'Pavitra']);
      expect(c.visibleRooms.map((r) => r.number), ['204', '305', '410']);

      c.selectedGroup.value = 'Param';
      expect(c.visibleRooms.map((r) => r.number), ['305']);
      expect(c.activeFilterCount, 1);

      c.selectedGroup.value = 'Pavitra';
      expect(c.visibleRooms.map((r) => r.number), ['204']);

      c.resetFilters();
      expect(c.selectedGroup.value, 'All');
      expect(c.visibleRooms, hasLength(3));
    });

    test('without a synced phonebook there are no groups to filter by', () async {
      final c = Get.put(RoomKeysController(roomGroupLoader: () async => throw StateError('no phonebook')));
      await until(() => !c.isLoading.value, reason: 'room keys load');
      expect(c.availableGroups, ['All']);
      expect(c.visibleRooms, hasLength(3));
    });

    test('a failed key list shows the error', () async {
      api.on('GET /room-keys', {'success': false, 'message': 'Server error'}, status: 500);
      final c = Get.put(RoomKeysController());
      await until(() => !c.isLoading.value, reason: 'room keys load');
      expect(c.hasError.value, isTrue);
    });
  });

  group('screens', () {
    late FakeApi api;

    setUpAll(() async {
      await loadDeviceLikeFonts();
      await serveGoogleFontsAsAssets();
    });

    setUp(() {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'admin-token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
      });
      Get.put(SessionStore());
      api = FakeApi()..install();
      Get.put(TagsRepository());
      Get.put(RoomKeysRepository());
      api.on('GET /students', {'success': true, 'data': students});
      api.on('GET /room-keys', {
        'success': true,
        'data': {'keys': hostelKeys()},
      });
    });

    tearDown(Get.reset);

    Future<RoomKeysController> pumpApp(WidgetTester tester, String route, {Object? arguments}) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: Routes.operatorRoomKeys,
          getPages: [
            GetPage(name: Routes.operatorRoomKeys, page: () => const RoomKeysScreen(), binding: RoomKeysBinding()),
            GetPage(
              name: Routes.operatorRoomKeysRoom,
              page: () => RoomKeysRoomScreen(room: Get.arguments?.toString() ?? ''),
              binding: RoomKeysBinding(),
            ),
          ],
        ),
      );
      if (route != Routes.operatorRoomKeys) {
        Get.toNamed(route, arguments: arguments);
      }
      final c = Get.find<RoomKeysController>();
      for (var i = 0; i < 40 && c.isLoading.value; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('the list shows each room with its door key and what is missing', (tester) async {
      await pumpApp(tester, Routes.operatorRoomKeys);

      expect(find.text('Room 204'), findsOneWidget);
      // The card is just the room and its warnings: no summary line, no tile.
      expect(find.textContaining('Door 204 (1)'), findsNothing);
      expect(find.textContaining('Cupboards 1/2'), findsNothing);
      // Bhavin (204) and Chirag (305) have no cupboard key yet.
      expect(find.text('1 without cupboard key'), findsNWidgets(2));
      expect(find.text('1 to check'), findsNWidgets(2)); // 305: left the hostel; 410: lost
      expect(find.text('Room 410'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a room lists each student with their cupboard key', (tester) async {
      await pumpApp(tester, Routes.operatorRoomKeysRoom, arguments: '204');

      expect(find.text('Room 204'), findsWidgets);
      expect(find.text('Door 204'), findsOneWidget);
      expect(find.text('Asha Patel'), findsOneWidget);
      expect(find.text('Cupboard 1123'), findsOneWidget);
      expect(find.text('Bhavin Shah'), findsOneWidget);
      expect(find.text('No cupboard key'), findsOneWidget);
      expect(find.text('Bank Code'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('setting up a room sends a cupboard key and a door copy for the student', (tester) async {
      await pumpApp(tester, Routes.operatorRoomKeysRoom, arguments: '204');
      api.on('POST /room-keys/batch', {
        'success': true,
        'data': {
          'keys': [
            keyJson(
              21,
              '204',
              'door',
              '204',
              status: 'assigned',
              studentId: 12,
              studentName: 'Bhavin Shah',
              studentRoom: '204',
            ),
            keyJson(
              22,
              '204',
              'cupboard',
              '1124',
              status: 'assigned',
              studentId: 12,
              studentName: 'Bhavin Shah',
              studentRoom: '204',
            ),
          ],
        },
      });

      await tester.tap(find.text('Add keys'));
      await tester.pumpAndSettle();
      expect(find.text('Keys for room 204'), findsOneWidget);

      // Asha already has a cupboard key, so only Bhavin's box is asked for.
      await tester.enterText(find.widgetWithText(TextField, 'Cupboard key number'), '1124');
      final bhavinDoorCopy = find.byType(CheckboxListTile).last;
      await tester.ensureVisible(bhavinDoorCopy);
      await tester.tap(bhavinDoorCopy);
      await tester.pump();

      final save = find.text('Save keys');
      await tester.ensureVisible(save);
      await tester.tap(save);
      for (var i = 0; i < 20 && api.called('POST /room-keys/batch').isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      final body = api.last('POST /room-keys/batch').data as Map;
      expect(body['room_number'], '204');
      expect(body['keys'], [
        {'key_type': 'door', 'key_number': '204', 'student_id': 12},
        {'key_type': 'cupboard', 'key_number': '1124', 'label': 'Cupboard A', 'student_id': 12},
      ]);
      expect(find.text('Keys for room 204'), findsNothing, reason: 'the sheet closes after saving');
      expect(find.text('No cupboard key'), findsNothing);

      // Let the "Keys Saved" snackbar run out.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });

  test('the room screen reads its room from the route', () {
    expect(const RoomKeysRoomScreen(room: ' 204 ').room, ' 204 ');
    expect(const RoomKeysScreen(), isA<RoomKeysScreen>());
  });
}
