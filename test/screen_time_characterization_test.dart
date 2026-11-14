import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_directory_controller.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Safety net for the Screen Time refactor (phase 1): pins down what the
/// screen's controller does today, request by request, so that splitting it
/// into a directory controller and a per-student controller (and a repository)
/// can be checked against the same expectations.
///
/// Complements `screen_time_student_id_test.dart` (id-only rule, search,
/// counts). HTTP is faked with a Dio interceptor, so everything runs offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const studentId = 903;

  late List<RequestOptions> requests;

  /// Per-test replies keyed by "METHOD /path"; return [_fail] to simulate a
  /// network/server error.
  late Map<String, Object? Function(RequestOptions)> replies;
  const fail = _Fail();

  Map<String, dynamic> student(int id, String name, {bool online = false}) => {
        'id': id,
        'name': name,
        'room': '306',
        'totalScreenTimeMinutes': 17,
        'nightScreenTimeMinutes': 0,
        'isScreenOn': false,
        'currentApp': 'Idle',
        'isOnline': online,
        'isLocked': false,
      };

  Object? defaults(RequestOptions o) {
    switch ('${o.method} ${o.path}') {
      case 'GET /screen-time/students':
        return {
          'success': true,
          'data': {
            'students': [student(studentId, 'Om')],
            'total': 1,
          },
        };
      case 'GET /screen-time/live/$studentId':
        return {
          'success': true,
          'data': {
            'studentId': studentId,
            'isOnline': true,
            'isScreenOn': true,
            'currentApp': 'YouTube',
            'totalScreenTimeMinutes': 95,
            'nightScreenTimeMinutes': 12,
            'appUsageBreakdown': [],
            'policy': null,
            'blockedPackages': [],
          },
        };
      case 'GET /screen-time/history/$studentId':
        return {
          'success': true,
          'data': {'studentId': studentId, 'records': []},
        };
      case 'GET /screen-time/policies/$studentId':
        return {
          'success': true,
          'data': {
            'policy': {
              'policy_version': 1,
              'is_locked': 0,
              'daily_limit_minutes': 0,
              'bedtime_start': null,
              'bedtime_end': null,
            },
            'apps': [],
            'blockedPackages': [],
          },
        };
      case 'GET /geofence/policy':
        return {
          'id': 'default_curfew',
          'name': 'Hostel Night Curfew',
          'startTime': '22:00',
          'endTime': '06:00',
          'isActive': true,
          'checkIntervalMinutes': 2,
          'repeatDays': ['Daily'],
        };
      case 'GET /screen-time/apps/requests':
        return {'success': true, 'data': []};
      case 'PUT /screen-time/policies/$studentId':
      case 'POST /screen-time/apps/rule':
        return {'success': true};
    }
    return null;
  }

  Iterable<RequestOptions> called(String route) =>
      requests.where((r) => '${r.method} ${r.path}' == route);

  Future<void> until(bool Function() condition, {String reason = ''}) async {
    for (var i = 0; i < 300; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail_(reason);
  }

  Future<StudentDetailController> openStudent() async {
    Get.routing.args = {'id': studentId, 'name': 'Om', 'room': '306'};
    final directory = Get.put(ScreenTimeDirectoryController());
    await until(() => directory.detail.value != null, reason: 'the student controller');
    final c = directory.detail.value!;
    await until(
      () => ['live', 'history', 'policies'].every(
        (p) => requests.any((r) => r.path == '/screen-time/$p/$studentId'),
      ),
      reason: 'live, history and policies of student $studentId',
    );
    // Let the first responses land before a test changes anything.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'test-token', 'name': 'Warden'}),
    });
    Get.testMode = true;
    requests = [];
    replies = {};
    Get.put(SessionStore());
    final api = ApiClient.create();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final route = '${options.method} ${options.path}';
      final data = replies.containsKey(route) ? replies[route]!(options) : defaults(options);
      if (data is _Fail) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 500),
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: data == null ? 404 : 200,
        data: data,
      ));
    }));
    Get.put(api);
  });

  tearDown(() {
    if (Get.isRegistered<StudentDetailController>(tag: '$studentId')) {
      Get.delete<StudentDetailController>(tag: '$studentId', force: true);
    }
    if (Get.isRegistered<ScreenTimeDirectoryController>()) {
      Get.delete<ScreenTimeDirectoryController>(force: true);
    }
    Get.reset();
    Get.routing.args = null;
  });

  group('directory paging', () {
    test('the first request asks for one page of pageSize from offset 0', () async {
      Get.routing.args = null;
      Get.put(ScreenTimeDirectoryController());
      await until(() => called('GET /screen-time/students').isNotEmpty, reason: 'directory request');

      final first = called('GET /screen-time/students').first;
      expect(first.queryParameters['limit'], ScreenTimeDirectoryController.pageSize);
      expect(first.queryParameters['offset'], 0);
    });

    test('the next page continues from what is already loaded', () async {
      replies['GET /screen-time/students'] = (o) {
        final offset = o.queryParameters['offset'] as int;
        final size = ScreenTimeDirectoryController.pageSize;
        return {
          'success': true,
          'data': {
            'students': [
              for (var i = 0; i < size; i++) student(1000 + offset + i, 'Student ${offset + i}'),
            ],
            'total': size * 2,
          },
        };
      };
      Get.routing.args = null;
      final c = Get.put(ScreenTimeDirectoryController());
      await until(() => c.allStudents.isNotEmpty, reason: 'first page');
      expect(c.hasMoreStudents.value, isTrue);

      await c.fetchMoreStudents();

      final offsets = called('GET /screen-time/students').map((r) => r.queryParameters['offset']).toList();
      expect(offsets, contains(ScreenTimeDirectoryController.pageSize));
      expect(c.hasMoreStudents.value, isFalse);
    });
  });

  group('opening one student', () {
    test('live status fills online, screen, current app and the totals', () async {
      final c = await openStudent();

      expect(c.isOnline.value, isTrue);
      expect(c.isScreenOn.value, isTrue);
      expect(c.currentApp.value, 'YouTube');
      expect(c.totalMinutesToday.value, 95);
      expect(c.nightMinutesToday.value, 12);
    });

    test('pending app requests are asked for that student only', () async {
      await openStudent();
      await until(
        () => called('GET /screen-time/apps/requests').any(
          (r) => r.queryParameters['student_id'] == '$studentId',
        ),
        reason: 'app requests of the student',
      );
      final forStudent = called('GET /screen-time/apps/requests')
          .where((r) => r.queryParameters['student_id'] == '$studentId');
      expect(forStudent.first.queryParameters['status'], 'pending');
    });
  });

  group('controls send partial updates and roll back on failure', () {
    test('locking sends only is_locked', () async {
      final c = await openStudent();
      await c.toggleDeviceLock(true);

      final put = called('PUT /screen-time/policies/$studentId').single;
      expect(put.data, {'is_locked': true});
      expect(c.isDeviceLocked.value, isTrue);
    });

    test('a failed lock is rolled back', () async {
      replies['PUT /screen-time/policies/$studentId'] = (_) => fail;
      final c = await openStudent();
      await c.toggleDeviceLock(true);

      expect(called('PUT /screen-time/policies/$studentId'), hasLength(1));
      expect(c.isDeviceLocked.value, isFalse);
    });

    test('Play Store is available by default when the policy has no restrict_app_installs', () async {
      final c = await openStudent();
      expect(c.playStoreBlocked.value, isFalse);
    });

    test('the Play Store state is read from restrict_app_installs (MySQL 0/1)', () async {
      replies['GET /screen-time/policies/$studentId'] = (_) => {
            'success': true,
            'data': {
              'policy': {'policy_version': 2, 'is_locked': 0, 'restrict_app_installs': 1},
              'apps': [],
              'blockedPackages': [],
            },
          };
      final c = await openStudent();
      await until(() => c.playStoreBlocked.value == true, reason: 'Play Store blocked from the policy');
    });

    test('blocking the Play Store sends only restrict_app_installs: true', () async {
      final c = await openStudent();
      await c.setPlayStoreBlocked(true);

      final put = called('PUT /screen-time/policies/$studentId').single;
      expect(put.data, {'restrict_app_installs': true});
      expect(c.playStoreBlocked.value, isTrue);
    });

    test('blocking the Play Store during an install pass also ends the pass', () async {
      final c = await openStudent();
      c.playStoreBlocked.value = true;
      c.installPassUntil.value = DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;
      await c.setPlayStoreBlocked(true);

      final put = called('PUT /screen-time/policies/$studentId').single;
      expect(put.data, {'restrict_app_installs': true, 'install_pass_until': 0});
      expect(c.hasActiveInstallPass, isFalse);
    });

    test('a failed Play Store change is rolled back', () async {
      replies['PUT /screen-time/policies/$studentId'] = (_) => fail;
      final c = await openStudent();
      await c.setPlayStoreBlocked(true);

      expect(called('PUT /screen-time/policies/$studentId'), hasLength(1));
      expect(c.playStoreBlocked.value, isFalse);
    });

    test('curfew and daily limit send exactly those three fields', () async {
      final c = await openStudent();
      await c.updateCurfewAndLimit(limitMinutes: 120, startBedtime: '22:30', endBedtime: '05:30');

      final put = called('PUT /screen-time/policies/$studentId').single;
      expect(put.data, {
        'daily_limit_minutes': 120,
        'bedtime_start': '22:30',
        'bedtime_end': '05:30',
      });
      expect(c.dailyLimitMinutes.value, 120);
    });

    test('turning the curfew off clears both bedtimes (null), keeping the daily limit', () async {
      replies['GET /screen-time/policies/$studentId'] = (_) => {
            'success': true,
            'data': {
              'policy': {
                'policy_version': 2,
                'is_locked': 0,
                'daily_limit_minutes': 90,
                'bedtime_start': '22:30',
                'bedtime_end': '05:30',
              },
              'apps': [],
              'blockedPackages': [],
            },
          };
      final c = await openStudent();
      expect(c.bedtimeStart.value, '22:30');

      await c.updateCurfewAndLimit(limitMinutes: 90);

      final put = called('PUT /screen-time/policies/$studentId').single;
      expect(put.data, {
        'daily_limit_minutes': 90,
        'bedtime_start': null,
        'bedtime_end': null,
      });
      expect(c.bedtimeStart.value, isEmpty);
      expect(c.bedtimeEnd.value, isEmpty);
      expect(c.dailyLimitMinutes.value, 90);
    });

    test('a failed curfew save restores the previous values', () async {
      replies['PUT /screen-time/policies/$studentId'] = (_) => fail;
      final c = await openStudent();
      await c.updateCurfewAndLimit(limitMinutes: 120, startBedtime: '22:30', endBedtime: '05:30');

      expect(c.dailyLimitMinutes.value, 0);
      expect(c.bedtimeStart.value, isEmpty);
    });

    test('blocking one app posts that single rule with the student id', () async {
      final c = await openStudent();
      await c.toggleAppBlock('com.instagram.android', 'Instagram', true);

      final rule = called('POST /screen-time/apps/rule').single;
      expect(rule.data, {
        'student_id': '$studentId',
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'is_blocked': true,
      });
      expect(c.blockedPackages, contains('com.instagram.android'));
    });

    test('a failed block is rolled back', () async {
      replies['POST /screen-time/apps/rule'] = (_) => fail;
      final c = await openStudent();
      await c.toggleAppBlock('com.instagram.android', 'Instagram', true);

      expect(c.blockedPackages, isNot(contains('com.instagram.android')));
    });
  });

  group('one controller per opened student', () {
    test('each student gets their own controller; closing one removes it', () async {
      Get.routing.args = null;
      final directory = Get.put(ScreenTimeDirectoryController());
      await until(() => directory.allStudents.isNotEmpty, reason: 'directory');

      directory.selectStudent(student(903, 'Om'));
      final om = directory.detail.value!;
      expect(Get.isRegistered<StudentDetailController>(tag: '903'), isTrue);
      await until(() => called('GET /screen-time/policies/903').isNotEmpty, reason: 'policy load');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await om.toggleDeviceLock(true);
      expect(om.isDeviceLocked.value, isTrue);

      // Opening another student drops the first controller; nothing carries over.
      directory.selectStudent(student(904, 'Asha'));
      final asha = directory.detail.value!;
      expect(identical(om, asha), isFalse);
      expect(Get.isRegistered<StudentDetailController>(tag: '903'), isFalse);
      expect(Get.isRegistered<StudentDetailController>(tag: '904'), isTrue);
      expect(asha.isDeviceLocked.value, isFalse);
      expect(asha.studentId, '904');

      directory.clearSelectedStudent();
      expect(directory.detail.value, isNull);
      expect(Get.isRegistered<StudentDetailController>(tag: '904'), isFalse);
      Get.delete<ScreenTimeDirectoryController>(force: true);
    });
  });

  group('app requests', () {
    test('approving posts the action and window, then drops the request', () async {
      replies['GET /screen-time/apps/requests'] = (_) => {
            'success': true,
            'data': [
              {'id': 7, 'student_id': studentId, 'app_name': 'Spotify'},
            ],
          };
      replies['POST /screen-time/apps/request/7/review'] = (_) => {'success': true};
      final c = await openStudent();
      await until(() => c.pendingAppRequests.isNotEmpty, reason: 'pending request');

      await c.reviewAppRequest(7, 'approve', durationMinutes: 30);

      final review = called('POST /screen-time/apps/request/7/review').single;
      expect(review.data, {'action': 'approve', 'duration_minutes': 30});
      expect(c.pendingAppRequests, isEmpty);
    });

    test('approving drops request when id is a string', () async {
      replies['GET /screen-time/apps/requests'] = (_) => {
            'success': true,
            'data': [
              {'id': '8', 'student_id': studentId, 'app_name': 'Zoom'},
            ],
          };
      replies['POST /screen-time/apps/request/8/review'] = (_) => {'success': true};
      final c = await openStudent();
      await until(() => c.pendingAppRequests.isNotEmpty, reason: 'pending request');

      await c.reviewAppRequest(8, 'approve', durationMinutes: 15);

      final review = called('POST /screen-time/apps/request/8/review').single;
      expect(review.data, {'action': 'approve', 'duration_minutes': 15});
      expect(c.pendingAppRequests, isEmpty);
    });
  });
}

void fail_(String reason) => fail('Timed out waiting for: $reason');

/// Sentinel a fake reply returns to make the request fail.
class _Fail {
  const _Fail();
}
