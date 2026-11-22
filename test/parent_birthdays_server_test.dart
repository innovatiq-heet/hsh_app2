import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/birthday/birthday_models.dart';
import 'package:hsh_app2/core/network/repository/birthday/birthday_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/birthday/controllers/admin_birthday_controller.dart';
import 'package:hsh_app2/features/birthday/models/parent_birthday.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Parents' own birthdays from the server (`todaysParentBirthdays`), the
/// "also wish parents" setting and the bot send (`send-parent-wish`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> celebrant({String role = 'father', bool sent = false}) => {
        'role': role,
        'parentName': 'Chirag Vasantlal Shah',
        'phone': '9974066375',
        'dob': '1972-11-22',
        'turning': 54,
        'students': [
          {'studentId': 812, 'name': 'Dharmik Shah', 'studentCode': '1131', 'room': '2', 'groupName': 'Paramanand', 'status': 'renewed-admission'},
          {'studentId': 913, 'name': 'Meet Shah', 'studentCode': '1200', 'room': '5', 'groupName': 'Paramanand', 'status': 'renewed-admission'},
        ],
        'alreadySentToday': sent,
      };

  group('server lists', () {
    test('a celebrant is read with its children, ids and sent state', () {
      final p = ParentBirthday.fromServer(celebrant());
      expect(p.role, 'father');
      expect(p.turning, 54);
      expect(p.studentIds, [812, 913]);
      expect(p.relationLine, 'Father of Dharmik Shah & Meet Shah');
      expect(p.bankCode, '1131');
      expect(p.room, '2');
      expect(p.isAlumni, isFalse);
      expect(p.alreadySent, isFalse);
      expect(ParentBirthday.fromServer(celebrant(sent: true)).alreadySent, isTrue);
    });

    test('a child who left makes the card alumni; bank codes are never taken as ids', () {
      final p = ParentBirthday.fromServer({
        ...celebrant(role: 'mother'),
        'students': [
          {'studentId': '0812', 'name': 'A', 'room': 'N/A', 'status': 'left'},
          {'studentId': 'HSH-1', 'name': 'B'},
        ],
      });
      expect(p.role, 'mother');
      expect(p.isAlumni, isTrue);
      // A leading zero is a bank code, not a students.id: never kept, so never sent.
      expect(p.studentIds, isEmpty);
    });

    test('the dashboard keeps the lists only when the API sends them', () {
      final withLists = BirthdayDashboardData.fromJson({
        'config': {'messageTemplate': 'Hi'},
        'todaysParentBirthdays': [celebrant()],
        'tomorrowsParentBirthdays': [],
      });
      expect(withLists.todaysParentBirthdays, hasLength(1));
      expect(withLists.tomorrowsParentBirthdays, isEmpty);

      final older = BirthdayDashboardData.fromJson({'config': {'messageTemplate': 'Hi'}});
      expect(older.todaysParentBirthdays, isNull);
    });

    test('fathers come first, then by name', () {
      final list = AdminBirthdayController.sortParents([
        ParentBirthday.fromServer({...celebrant(role: 'mother'), 'parentName': 'Asha'}),
        ParentBirthday.fromServer({...celebrant(), 'parentName': 'Zubin'}),
        ParentBirthday.fromServer({...celebrant(), 'parentName': 'Amit'}),
      ]);
      expect(list.map((p) => p.parentName), ['Amit', 'Zubin', 'Asha']);
    });
  });

  group('"also wish parents" setting', () {
    test('read from the config and sent back only to a server that supports it', () {
      final cfg = BirthdayConfigModel.fromJson({
        'messageTemplate': 'Hi',
        'activeFatherTemplateId': null,
        'includeParentBirthdays': true,
      });
      expect(cfg.includeParentBirthdays, isTrue);
      expect(cfg.copyWith(includeParentBirthdays: false).toJson()['includeParentBirthdays'], isFalse);

      final older = BirthdayConfigModel.fromJson({'messageTemplate': 'Hi'});
      expect(older.copyWith(includeParentBirthdays: true).toJson().containsKey('includeParentBirthdays'), isFalse);
    });
  });

  group('bot send', () {
    late FakeApi api;

    setUp(() {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'admin-token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
      });
      Get.put(SessionStore());
      api = FakeApi()..install();
    });

    tearDown(Get.reset);

    test('sends role, numeric student id and the chosen number', () async {
      api.on('POST /whatsapp/birthday/send-parent-wish', {'success': true, 'data': {'role': 'father'}});
      await BirthdayRepository().sendParentWish(role: 'father', studentId: 812, accountId: 'wa1');
      expect(api.last('POST /whatsapp/birthday/send-parent-wish').data, {'role': 'father', 'studentId': 812, 'accountId': 'wa1'});

      await BirthdayRepository().sendParentWish(role: 'mother', studentId: 812);
      expect(api.last('POST /whatsapp/birthday/send-parent-wish').data, {'role': 'mother', 'studentId': 812});
    });

    test('already wished today (409) is its own error; others carry the server message', () async {
      api.on('POST /whatsapp/birthday/send-parent-wish',
          {'success': false, 'message': 'The father was already wished today'}, status: 409);
      await expectLater(
        BirthdayRepository().sendParentWish(role: 'father', studentId: 812),
        throwsA(isA<ParentAlreadyWishedException>()
            .having((e) => e.message, 'message', 'The father was already wished today')),
      );

      api.on('POST /whatsapp/birthday/send-parent-wish',
          {'success': false, 'code': 'WHATSAPP_NOT_CONNECTED', 'message': 'WhatsApp is currently not connected.'},
          status: 400);
      await expectLater(
        BirthdayRepository().sendParentWish(role: 'father', studentId: 812),
        throwsA(predicate((e) => e.toString().contains('WhatsApp is currently not connected.'))),
      );
    });
  });
}
