import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/alumni/alumni_current_details.dart';
import 'package:hsh_app2/core/network/api_exception.dart';
import 'package:hsh_app2/core/network/repository/alumni/alumni_current_details_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/phonebook/services/student_id_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Alumni "Current address & work": who it is saved for, and what is sent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('finding the student by Aadhar', () {
    final rows = [
      {'id': 812, 'aadhar': '3423 7411 5218', 'student_code': '1131'},
      {'id': 913, 'aadhar': '787338261868', 'student_code': '0812'},
      {'id': 914, 'aadhar': '111122223333'},
      {'id': 915, 'aadhar': '111122223333'}, // the same Aadhar twice: not certain
      {'id': '0768', 'aadhar': '999988887777'}, // a bank code, not an id
    ];

    test('the exact 12 digits, one student', () {
      expect(StudentIdResolver.idByAadhar(rows, '342374115218'), 812);
      expect(StudentIdResolver.idByAadhar(rows, '7873-3826-1868'), 913);
    });

    test('no guess: two students, a bank code row, a short or missing number', () {
      expect(StudentIdResolver.idByAadhar(rows, '111122223333'), isNull);
      expect(StudentIdResolver.idByAadhar(rows, '999988887777'), isNull);
      expect(StudentIdResolver.idByAadhar(rows, '0812'), isNull);
      expect(StudentIdResolver.idByAadhar(rows, null), isNull);
      expect(StudentIdResolver.idByAadhar(rows, '123456789012'), isNull);
    });
  });

  group('details', () {
    test('read from the server, blanks as missing', () {
      final d = AlumniCurrentDetails.fromJson({
        'current_city': 'Ahmedabad',
        'current_company': ' Infosys ',
        'current_designation': '',
        'current_address': null,
        'details_updated_by': 'Super Admin',
        'details_updated_at': '2026-11-24T10:15:00.000Z',
      });
      expect(d.city, 'Ahmedabad');
      expect(d.company, 'Infosys');
      expect(d.role, isNull);
      expect(d.address, isNull);
      expect(d.updatedBy, 'Super Admin');
      expect(d.updatedAt, isNotNull);
      expect(d.isEmpty, isFalse);
      expect(AlumniCurrentDetails.fromJson({}).isEmpty, isTrue);
    });

    test('only changed fields are sent; a cleared one as ""', () {
      const before = AlumniCurrentDetails(city: 'Surat', company: 'TCS', role: 'Tester');
      const after = AlumniCurrentDetails(city: 'Ahmedabad', company: 'TCS', role: null, address: 'Satellite');
      expect(AlumniCurrentDetails.changes(before, after), {
        'current_city': 'Ahmedabad',
        'current_designation': '',
        'current_address': 'Satellite',
      });
      expect(AlumniCurrentDetails.changes(before, before), isEmpty);
    });
  });

  group('repository', () {
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

    test('reads and saves by numeric students.id', () async {
      const path = '/alumni/admin/students/812/current-details';
      api.on('GET $path', {'success': true, 'data': {'student_id': 812, 'current_city': null}});
      api.on('PUT $path', {
        'success': true,
        'data': {'student_id': 812, 'current_city': 'Ahmedabad', 'details_updated_by': 'Super Admin'},
      });
      final repo = AlumniCurrentDetailsRepository();

      expect((await repo.fetch(812)).isEmpty, isTrue);
      final saved = await repo.save(812, {'current_city': 'Ahmedabad'});
      expect(api.last('PUT $path').data, {'current_city': 'Ahmedabad'});
      expect(saved.city, 'Ahmedabad');
    });

    test("the server's message comes through", () async {
      api.on('PUT /alumni/admin/students/812/current-details',
          {'success': false, 'message': 'current_company must be at most 100 characters'}, status: 400);
      await expectLater(
        AlumniCurrentDetailsRepository().save(812, {'current_company': 'x' * 101}),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'current_company must be at most 100 characters')),
      );
    });
  });
}
