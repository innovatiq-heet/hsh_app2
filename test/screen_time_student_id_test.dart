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
      case '/screen-time/apps/rule':
        return {
          'success': true,
          'message': 'App rule updated successfully',
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

  test('setting app time limit sends student id and daily_limit_minutes', () async {
    final controller = await open({'id': studentId, 'name': 'Asha Patel'});
    await controller.setAppLimit('com.instagram.android', 'Instagram', 45);

    final ruleReq = requests.firstWhere((r) => r.path == '/screen-time/apps/rule');
    expect(ruleReq.data['student_id'], '$studentId');
    expect(ruleReq.data['package_name'], 'com.instagram.android');
    expect(ruleReq.data['daily_limit_minutes'], 45);
    expect(controller.appLimits['com.instagram.android'], 45);
    expectNoBankCodeUsed();
  });

  test('multi-field search matches room, aadhar with leading zero stripped, and clearSearch restores', () async {
    final controller = await open(null);
    expect(controller.filteredStudents, isNotEmpty);

    // Search by room
    controller.filterStudents('204');
    expect(controller.filteredStudents.length, 1);
    expect(controller.filteredStudents.first['name'], 'Asha Patel');

    // Search by student code / bank code without leading zero ("768" matching "0768")
    controller.filterStudents('768');
    expect(controller.filteredStudents.length, 1);
    expect(controller.filteredStudents.first['name'], 'Asha Patel');

    // Search non-matching
    controller.filterStudents('NonExistent');
    expect(controller.filteredStudents, isEmpty);

    // clearSearch restores
    controller.clearSearch();
    expect(controller.filteredStudents, isNotEmpty);
    expect(controller.searchFilterController.text, isEmpty);
  });

  test('loadMoreItems increments visible student count for lazy rendering', () async {
    final controller = await open(null);
    expect(controller.visibleStudentCount.value, 20);

    // Populate 35 mock students to exceed uiBatchSize (20)
    final mockStudents = List.generate(35, (i) => {
      'id': 2000 + i,
      'name': 'Student $i',
      'room': '${100 + i}',
      'totalScreenTimeMinutes': i,
    });
    controller.allStudents.assignAll(mockStudents);
    controller.filterStudents('');
    controller.visibleStudentCount.value = 20;

    expect(controller.filteredStudents.length, 35);
    expect(controller.visibleStudentCount.value, 20);

    // Call loadMoreItems: should expand from 20 to 35
    await controller.loadMoreItems();
    expect(controller.visibleStudentCount.value, 35);
  });

  test('toBool coercions handle MySQL 1/0, bool, and string correctly', () {
    expect(StudentScreenTimeController.toBool(true), isTrue);
    expect(StudentScreenTimeController.toBool(false), isFalse);
    expect(StudentScreenTimeController.toBool(1), isTrue);
    expect(StudentScreenTimeController.toBool(0), isFalse);
    expect(StudentScreenTimeController.toBool('1'), isTrue);
    expect(StudentScreenTimeController.toBool('0'), isFalse);
    expect(StudentScreenTimeController.toBool('true'), isTrue);
    expect(StudentScreenTimeController.toBool('false'), isFalse);
    expect(StudentScreenTimeController.toBool(null), isFalse);
  });

  test('isStudentOnline and isStudentOffline work with MySQL integers and fallback', () {
    final sOnlineInt = {'id': 1, 'isOnline': 1, 'isScreenOn': 1};
    final sOfflineInt = {'id': 2, 'isOnline': 0, 'isScreenOn': 0};
    final sOnlineBool = {'id': 3, 'is_online': true, 'is_screen_on': false};
    final sRecentSeen = {
      'id': 4,
      'last_seen': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    };
    final sOldSeen = {
      'id': 5,
      'last_seen': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
    };

    expect(StudentScreenTimeController.isStudentOnline(sOnlineInt), isTrue);
    expect(StudentScreenTimeController.isStudentOffline(sOnlineInt), isFalse);
    expect(StudentScreenTimeController.isStudentScreenOn(sOnlineInt), isTrue);

    expect(StudentScreenTimeController.isStudentOnline(sOfflineInt), isFalse);
    expect(StudentScreenTimeController.isStudentOffline(sOfflineInt), isTrue);
    expect(StudentScreenTimeController.isStudentScreenOn(sOfflineInt), isFalse);

    expect(StudentScreenTimeController.isStudentOnline(sOnlineBool), isTrue);
    expect(StudentScreenTimeController.isStudentScreenOn(sOnlineBool), isFalse);

    expect(StudentScreenTimeController.isStudentOnline(sRecentSeen), isTrue);
    expect(StudentScreenTimeController.isStudentOnline(sOldSeen), isFalse);
  });

  test('StudentScreenTimeController directoryCount and directoryFilter handle Online and Offline correctly', () {
    final controller = StudentScreenTimeController();
    controller.allStudents.assignAll([
      {'id': 1, 'name': 'Alpha', 'isOnline': 1},
      {'id': 2, 'name': 'Beta', 'isOnline': 0},
      {'id': 3, 'name': 'Gamma', 'isOnline': true},
      {'id': 4, 'name': 'Delta', 'isOnline': false},
    ]);

    expect(controller.directoryCount('Online'), 2);
    expect(controller.directoryCount('Offline'), 2);

    controller.setDirectoryFilter('Online');
    expect(controller.filteredStudents.length, 2);
    expect(controller.filteredStudents.map((s) => s['name']).toList(), ['Alpha', 'Gamma']);

    controller.setDirectoryFilter('Offline');
    expect(controller.filteredStudents.length, 2);
    expect(controller.filteredStudents.map((s) => s['name']).toList(), ['Beta', 'Delta']);
  });

  test('extractRecordDate normalizes ISO strings, spaces, and diverse date keys', () {
    expect(StudentScreenTimeController.extractRecordDate({'date': '2026-10-17'}), '2026-10-17');
    expect(StudentScreenTimeController.extractRecordDate({'usage_date': '2026-10-17 00:00:00'}), '2026-10-17');
    expect(StudentScreenTimeController.extractRecordDate({'created_at': '2026-10-17T08:30:00.000Z'}), '2026-10-17');
    expect(StudentScreenTimeController.extractRecordDate('2026-10-17 14:22:00'), '2026-10-17');
  });

  test('date-wise screen time and app usage resolves previous day from history records', () {
    final controller = StudentScreenTimeController();
    controller.totalMinutesToday.value = 45;
    controller.historyRecords.assignAll([
      {
        'usage_date': '2026-10-17 00:00:00',
        'total_screen_time_minutes': 120,
        'night_screen_time_minutes': 30,
        'appUsageBreakdown': jsonEncode([
          {'packageName': 'com.whatsapp', 'appName': 'WhatsApp', 'usage_minutes': 70},
          {'packageName': 'com.google.android.youtube', 'appName': 'YouTube', 'usage_minutes': 50},
        ]),
      },
      {
        'date': '2026-10-16',
        'totalMinutes': 90,
        'nightMinutes': 0,
        'apps': [
          {'packageName': 'com.instagram.android', 'appName': 'Instagram', 'minutes': 90},
        ],
      },
    ]);

    // Select today
    controller.selectDate(controller.todayDateStr);
    expect(controller.isTodaySelected, isTrue);
    expect(controller.selectedDayTotalMinutes, 45);

    // Select previous day (2026-10-17)
    controller.selectDate('2026-10-17');
    expect(controller.isTodaySelected, isFalse);
    expect(controller.effectiveSelectedDate, '2026-10-17');
    expect(controller.selectedDayTotalMinutes, 120);
    expect(controller.selectedDayNightMinutes, 30);
    expect(controller.currentDayRawApps.length, 2);

    final apps = controller.displayAppsList;
    expect(apps.any((a) => a['packageName'] == 'com.whatsapp' && a['minutes'] == 70), isTrue);
    expect(apps.any((a) => a['packageName'] == 'com.google.android.youtube' && a['minutes'] == 50), isTrue);

    // Select earlier day (2026-10-16)
    controller.selectDate('2026-10-16');
    expect(controller.selectedDayTotalMinutes, 90);
    expect(controller.currentDayRawApps.length, 1);
    expect(controller.currentDayRawApps.first['packageName'], 'com.instagram.android');

    // Select day with no breakdown array, but recorded active current_app (e.g. Settings Suggestions)
    controller.historyRecords.add({
      'date': '2026-10-10',
      'total_screen_time_minutes': 621,
      'current_app': 'Settings Suggestions',
    });
    controller.selectDate('2026-10-10');
    expect(controller.selectedDayTotalMinutes, 621);
    expect(controller.currentDayRawApps.length, 1);
    expect(controller.currentDayRawApps.first['appName'], 'Settings Suggestions');
  });
}


