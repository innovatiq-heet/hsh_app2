import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/student_screen_time_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for "View Individual Screen Time" opening the wrong
/// student: the Screen Time screen must identify students only by numeric
/// `students.id`, never by bank code (the API reads "0768" as student #768).
///
/// HTTP is faked with a Dio interceptor that records every request the
/// controller makes, so these run offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A directory entry whose bank code ("0768") would collide with another
  // student's id if it were ever used as an identifier.
  const studentId = 1043;
  const bankCode = '0768';
  final directoryEntry = {
    'id': studentId,
    'name': 'Asha Patel',
    'aadhar': bankCode,
    'room': '204',
    'totalScreenTimeMinutes': 12,
    'nightScreenTimeMinutes': 0,
    'isScreenOn': false,
    'currentApp': 'Idle',
    'isOnline': true,
    'isLocked': false,
  };

  late List<RequestOptions> requests;

  Object? fakeResponse(RequestOptions o) {
    switch (o.path) {
      case '/screen-time/students':
        return {
          'success': true,
          'data': {'students': [directoryEntry]},
        };
      case '/screen-time/live/$studentId':
        return {
          'success': true,
          'data': {'studentId': studentId, 'isOnline': true, 'appUsageBreakdown': [], 'policy': null, 'blockedPackages': []},
        };
      case '/screen-time/history/$studentId':
        return {
          'success': true,
          'data': {'studentId': studentId, 'records': []},
        };
      case '/screen-time/policies/$studentId':
        return {
          'success': true,
          'data': {
            'policy': {'policy_version': 1, 'is_locked': 0, 'daily_limit_minutes': 0, 'bedtime_start': null, 'bedtime_end': null},
            'apps': [],
            'blockedPackages': [],
          },
        };
      case '/geofence/policy':
        return {
          'id': 'default_curfew',
          'name': 'Hostel Night Curfew',
          'startTime': '22:00',
          'endTime': '06:00',
          'isActive': true,
          'checkIntervalMinutes': 2,
          'repeatDays': ['Daily'],
        };
    }
    return null;
  }

  Iterable<String> paths() => requests.map((r) => r.uri.toString());

  Future<void> until(bool Function() condition, {String reason = ''}) async {
    for (var i = 0; i < 200; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for: $reason\nRequests: ${paths().toList()}');
  }

  Future<StudentScreenTimeController> open(Map<String, dynamic>? args) async {
    Get.routing.args = args;
    final controller = Get.put(StudentScreenTimeController());
    await until(() => requests.any((r) => r.path == '/screen-time/students'), reason: 'directory request');
    return controller;
  }

  void expectNoBankCodeUsed() {
    for (final uri in paths()) {
      expect(uri, isNot(contains(bankCode)), reason: 'a bank code must never be sent as an identifier');
      expect(uri, isNot(contains('HSH-')));
      expect(uri, isNot(contains('aadhar')));
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'test-token', 'name': 'Warden'}),
    });
    Get.testMode = true;
    requests = [];
    Get.put(SessionStore());
    final api = ApiClient.create();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final data = fakeResponse(options);
      handler.resolve(Response(requestOptions: options, statusCode: data == null ? 404 : 200, data: data));
    }));
    Get.put(api);
  });

  tearDown(() {
    if (Get.isRegistered<StudentScreenTimeController>()) Get.delete<StudentScreenTimeController>(force: true);
    Get.reset();
    Get.routing.args = null;
  });

  test('phonebook arguments (name only) open the directory searched by name', () async {
    final controller = await open({'name': 'Asha Patel', 'room': '204'});

    expect(controller.selectedStudent.value, isNull, reason: 'nothing may be guessed from a name');
    expect(controller.searchFilterController.text, 'Asha Patel');
    final directoryRequest = requests.firstWhere((r) => r.path == '/screen-time/students');
    expect(directoryRequest.queryParameters['search'], 'Asha Patel');
    expect(requests.where((r) => r.path.startsWith('/screen-time/live')), isEmpty);
    expectNoBankCodeUsed();
  });

  test('old-style bank-code arguments are ignored', () async {
    final controller = await open({'studentId': 'HSH-$bankCode', 'aadhar': bankCode, 'name': 'Asha Patel'});

    expect(controller.selectedStudent.value, isNull);
    expectNoBankCodeUsed();
  });

  test('picking the student from the directory uses only the numeric id', () async {
    final controller = await open({'name': 'Asha Patel'});
    expect(controller.filteredStudents, hasLength(1));

    controller.selectStudent(controller.filteredStudents.first);
    await until(
      () => ['live', 'history', 'policies'].every((p) => requests.any((r) => r.path == '/screen-time/$p/$studentId')),
      reason: 'live, history and policies requests by id',
    );

    expect(requests.where((r) => r.path.startsWith('/screen-time/live')).map((r) => r.path).toSet(), {'/screen-time/live/$studentId'});
    expectNoBankCodeUsed();
  });

  test('an explicit numeric id opens that student directly', () async {
    final controller = await open({'id': studentId, 'name': 'Asha Patel'});

    expect(controller.selectedStudent.value, isNotNull);
    expect(controller.openedWithDirectTarget.value, isTrue);
    await until(() => requests.any((r) => r.path == '/screen-time/live/$studentId'), reason: 'live request by id');
    expectNoBankCodeUsed();
  });

  test('an id with a leading zero is a bank code, not an id', () async {
    final controller = await open({'id': bankCode, 'name': 'Asha Patel'});

    expect(controller.selectedStudent.value, isNull);
    expectNoBankCodeUsed();
  });

  test('directory refreshes send the search box text to the server', () async {
    final controller = await open(null);
    expect(requests.first.queryParameters.containsKey('search'), isFalse);

    controller.searchFilterController.text = 'Asha';
    await controller.fetchStudentsList(silent: true);

    expect(requests.last.path, '/screen-time/students');
    expect(requests.last.queryParameters['search'], 'Asha');
  });
}
