import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/api_exception.dart';
import 'package:hsh_app2/core/network/repository/screentime/screen_time_repository.dart';
import 'package:hsh_app2/core/network/responses/screentime/students_page.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// `/screen-time/*` requests and response shapes, with HTTP faked offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late ScreenTimeRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'test-token', 'name': 'Warden'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    repo = ScreenTimeRepository();
  });

  tearDown(Get.reset);

  group('StudentsPage.parse', () {
    test('object with students and a total', () {
      final page = StudentsPage.parse({
        'data': {
          'students': [
            {'id': 1},
            {'id': 2},
          ],
          'total': '340',
        },
      });
      expect(page.students, hasLength(2));
      expect(page.total, 340);
      expect(page.totalReported, isTrue);
      expect(page.hasPayload, isTrue);
    });

    test('the total can sit under pagination.total', () {
      final page = StudentsPage.parse({
        'data': {
          'students': [{'id': 1}],
          'pagination': {'total': 12},
        },
      });
      expect(page.total, 12);
    });

    test('a bare list has no total, only the page length', () {
      final page = StudentsPage.parse([
        {'id': 1},
        {'id': 2},
      ]);
      expect(page.total, 2);
      expect(page.totalReported, isFalse);
      expect(page.hasPayload, isTrue);
    });

    test('an empty students list is still a payload; an unexpected body is not', () {
      expect(
        StudentsPage.parse({'data': {'students': []}}).hasPayload,
        isTrue,
      );
      expect(StudentsPage.parse({'data': {'unrelated': 1}}).hasPayload, isFalse);
      expect(StudentsPage.parse(null).hasPayload, isFalse);
    });
  });

  group('requests', () {
    test('students: limit, offset and search (only when given)', () async {
      api.on('GET /screen-time/students', {'data': {'students': [], 'total': 0}});

      await repo.students(limit: 20, offset: 40, search: 'om');
      await repo.students(limit: 20, offset: 0, search: '');

      final q = api.called('GET /screen-time/students').map((r) => r.queryParameters).toList();
      expect(q[0], {'limit': 20, 'offset': 40, 'search': 'om'});
      expect(q[1], {'limit': 20, 'offset': 0});
    });

    test('history for a day sends the date', () async {
      api.on('GET /screen-time/history/903', {'data': {}});
      await repo.history('903', date: '2026-10-30');
      expect(api.last('GET /screen-time/history/903').queryParameters, {'date': '2026-10-30'});
    });

    test('an app rule omits the limit unless one is given', () async {
      api.on('POST /screen-time/apps/rule', {'success': true});

      await repo.setAppRule(
        studentId: '903',
        packageName: 'com.x',
        appName: 'X',
        isBlocked: true,
      );
      await repo.setAppRule(
        studentId: '903',
        packageName: 'com.x',
        appName: 'X',
        isBlocked: false,
        dailyLimitMinutes: 45,
      );

      final sent = api.called('POST /screen-time/apps/rule').map((r) => r.data).toList();
      expect(sent[0], {
        'student_id': '903',
        'package_name': 'com.x',
        'app_name': 'X',
        'is_blocked': true,
      });
      expect(sent[1]['daily_limit_minutes'], 45);
    });

    test('a policy update sends only the given fields', () async {
      api.on('PUT /screen-time/policies/903', {'success': true});
      await repo.updatePolicy('903', {'is_locked': true});
      expect(api.last('PUT /screen-time/policies/903').data, {'is_locked': true});
    });

    test('pending requests: filtered by student when given', () async {
      api.on('GET /screen-time/apps/requests', {
        'data': [
          {'id': 7},
          'not a map',
        ],
      });

      final all = await repo.pendingAppRequests();
      final one = await repo.pendingAppRequests(studentId: '903');

      expect(all, [
        {'id': 7},
      ]);
      final q = api.called('GET /screen-time/apps/requests').map((r) => r.queryParameters).toList();
      expect(q[0], {'status': 'pending'});
      expect(q[1], {'status': 'pending', 'student_id': '903'});
      expect(one, hasLength(1));
    });

    test('reviewAppRequest falls back to plural route when singular 404s', () async {
      api.on('POST /screen-time/apps/request/9/review', {'message': 'Not found'}, status: 404);
      api.on('POST /screen-time/apps/requests/9/review', {'success': true});

      await repo.reviewAppRequest(9, 'approve', durationMinutes: 15);

      final calls = api.called('POST /screen-time/apps/requests/9/review');
      expect(calls, hasLength(1));
      expect(calls.single.data, {'action': 'approve', 'duration_minutes': 15});
    });
  });

  group('errors', () {
    test('a failed call throws ApiException with the backend message', () async {
      api.on('PUT /screen-time/policies/903', {'message': 'Student not found'}, status: 404);
      expect(
        () => repo.updatePolicy('903', {'is_locked': true}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });
}
