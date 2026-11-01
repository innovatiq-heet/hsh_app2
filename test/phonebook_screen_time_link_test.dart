import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/phonebook/controllers/phonebook_controller.dart';
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_directory_controller.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

PhonebookStudent _student({String name = 'Om Shambhupras', String? room = '306', String? bank = '0768'}) =>
    PhonebookStudent(
      id: 'stu_1',
      studentId: 'HSH-$bank',
      name: name,
      enrollmentNumber: bank ?? '',
      department: 'Param',
      batch: 'ACTIVE',
      room: room,
      bankCode: bank,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'test-token', 'name': 'Test', 'room': ''}),
    });
    Get.put(SessionStore());
    api = FakeApi();
    api.install();
  });

  tearDown(Get.reset);

  group('phonebook -> Screen Time student id', () {
    test('uses the id of the one entry whose bank code AND name match', () async {
      api.on('GET /screen-time/students', {
        'data': {
          'students': [
            // Same name, another student (different bank code).
            {'id': 931, 'name': 'Om Shambhupras', 'room': '306', 'bankCode': '1043'},
            {'id': 903, 'name': 'Om Shambhupras', 'room': '306', 'bankCode': '0768'},
          ],
        },
      });
      final id = await PhonebookController().findScreenTimeStudentId(_student());
      expect(id, '903');
    });

    test('is null when the bank code matches nobody (opens a name search instead)', () async {
      api.on('GET /screen-time/students', {
        'data': {
          'students': [
            {'id': 931, 'name': 'Om Shambhupras', 'room': '306', 'bankCode': '1043'},
          ],
        },
      });
      expect(await PhonebookController().findScreenTimeStudentId(_student()), isNull);
    });

    test('is null when two entries would match (never guess)', () async {
      api.on('GET /screen-time/students', {
        'data': {
          'students': [
            {'id': 903, 'name': 'Om Shambhupras', 'room': '306', 'bankCode': '0768'},
            {'id': 904, 'name': 'Om Shambhupras', 'room': '306', 'bankCode': '0768'},
          ],
        },
      });
      expect(await PhonebookController().findScreenTimeStudentId(_student()), isNull);
    });

    test('a bank code is never taken as an id', () async {
      api.on('GET /screen-time/students', {'data': {'students': []}});
      final id = await PhonebookController().findScreenTimeStudentId(_student());
      expect(id, isNull);
      for (final r in api.called('GET /screen-time/students')) {
        expect(r.queryParameters.containsKey('id'), isFalse);
      }
    });

    test('is null on an API error', () async {
      api.on('GET /screen-time/students', {'message': 'boom'}, status: 500);
      expect(await PhonebookController().findScreenTimeStudentId(_student()), isNull);
    });
  });

  group('Screen Time list merge', () {
    test('two students sharing a phone or bank code keep their own ids', () {
      final c = ScreenTimeDirectoryController();
      c.mergeServerStudentsForTest([
        {'id': 903, 'name': 'Om A', 'room': '306', 'phone': '9876543210', 'bankCode': '0768'},
      ]);
      // Another student (931) with the same phone / bank code must not
      // overwrite 903's id.
      c.mergeServerStudentsForTest([
        {'id': 931, 'name': 'Om B', 'room': '307', 'phone': '9876543210', 'bankCode': '0768'},
      ]);
      final ids = c.allStudents.map((s) => s['id'].toString()).toList();
      expect(ids, containsAll(['903', '931']));
      expect(c.allStudents.firstWhere((s) => s['name'] == 'Om A')['id'].toString(), '903');
    });
  });
}
