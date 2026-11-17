import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_directory_controller.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:hsh_app2/features/screentime/views/student_screen_time_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

/// Screen Time for a student leader: only the students of the leader's own
/// group, from the list to app requests and directly opened students. Plus
/// the header's back button.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;

  /// The group `/screen-time/students` reports for the caller (null: none).
  String? leaderGroup;

  Map<String, dynamic> student(int id, String name, String group) => {
        'id': id,
        'name': name,
        'room': '204',
        'groupName': group,
        'totalScreenTimeMinutes': 30,
        'nightScreenTimeMinutes': 0,
        'isOnline': true,
        'isLocked': false,
      };

  final param = [student(1043, 'Asha Patel', 'Param'), student(1044, 'Bhavin Shah', 'Param')];
  final everyone = [...param, student(1050, 'Chirag Joshi', 'Pavitra')];

  Object? reply(RequestOptions o) {
    final path = o.path;
    if (path == '/screen-time/students') {
      final group = o.queryParameters['group']?.toString();
      final search = (o.queryParameters['search'] ?? '').toString().toLowerCase();
      final rows = everyone
          .where((s) => group == null || s['groupName'] == group)
          .where((s) => search.isEmpty || s['name'].toString().toLowerCase().contains(search))
          .toList();
      return {
        'success': true,
        'data': {
          'students': rows,
          'total': rows.length,
          'onlineCount': rows.length,
          'offlineCount': 0,
          'lockedCount': 0,
          'leaderGroupName': leaderGroup,
        },
      };
    }
    if (path == '/screen-time/apps/requests') {
      return {
        'success': true,
        'data': [
          {'id': 1, 'studentId': 1043, 'studentName': 'Asha Patel', 'packageName': 'com.a', 'appName': 'A'},
          {'id': 2, 'studentId': 1050, 'studentName': 'Chirag Joshi', 'packageName': 'com.b', 'appName': 'B'},
        ],
      };
    }
    if (path == '/geofence/policy') {
      return {'id': 'default_curfew', 'startTime': '22:00', 'endTime': '06:00', 'isActive': true};
    }
    if (path.startsWith('/screen-time/live/')) {
      return {'success': true, 'data': {'isOnline': true, 'appUsageBreakdown': [], 'policy': null, 'blockedPackages': []}};
    }
    if (path.startsWith('/screen-time/history/')) {
      return {'success': true, 'data': {'records': []}};
    }
    if (path.startsWith('/screen-time/policies/')) {
      return {'success': true, 'data': {'policy': {'policy_version': 1, 'is_locked': 0}, 'apps': [], 'blockedPackages': []}};
    }
    return null;
  }

  Iterable<RequestOptions> directoryCalls() => requests.where((r) => r.path == '/screen-time/students');

  Future<void> until(bool Function() condition, {String reason = ''}) async {
    for (var i = 0; i < 300; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for: $reason');
  }

  Future<void> signIn(String role) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': role, 'token': 'token', 'name': 'Ravi'}),
    });
    Get.testMode = true;
    requests = [];
    final session = Get.put(SessionStore());
    final api = ApiClient.create();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final data = reply(options);
      handler.resolve(Response(requestOptions: options, statusCode: data == null ? 404 : 200, data: data));
    }));
    Get.put(api);
    await until(() => session.currentSession != null, reason: 'the session');
  }

  setUp(() => leaderGroup = 'Param');

  tearDown(() {
    for (final id in [1043, 1044, 1050]) {
      if (Get.isRegistered<StudentDetailController>(tag: '$id')) {
        Get.delete<StudentDetailController>(tag: '$id', force: true);
      }
    }
    if (Get.isRegistered<ScreenTimeDirectoryController>()) {
      Get.delete<ScreenTimeDirectoryController>(force: true);
    }
    Get.reset();
    Get.routing.args = null;
  });

  Future<ScreenTimeDirectoryController> open({Map<String, dynamic>? args}) async {
    Get.routing.args = args;
    final c = Get.put(ScreenTimeDirectoryController());
    await until(() => directoryCalls().length >= (c.isLeaderView ? 2 : 1) && !c.isLoadingStudents.value,
        reason: 'the student list');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return c;
  }

  group('leader', () {
    test('sees only the students of their own group', () async {
      await signIn('leader');
      final c = await open();

      expect(c.isLeaderView, isTrue);
      expect(c.leaderGroupName.value, 'Param');
      expect(c.allStudents.map((s) => s['name']), ['Asha Patel', 'Bhavin Shah']);
      expect(c.filteredStudents.map((s) => s['name']), ['Asha Patel', 'Bhavin Shah']);
      expect(c.directoryCount('All'), 2);

      // Only the one-row group lookup goes out without a group.
      final calls = directoryCalls().toList();
      expect(calls.first.queryParameters['limit'], 1);
      expect(calls.first.queryParameters.containsKey('group'), isFalse);
      for (final r in calls.skip(1)) {
        expect(r.queryParameters['group'], 'Param');
        expect(r.queryParameters['limit'], ScreenTimeDirectoryController.leaderGroupPageSize);
      }
    });

    test('a search stays inside the group', () async {
      await signIn('leader');
      final c = await open();
      c.searchFilterController.text = 'Chirag';
      c.onSearchSubmitted('Chirag');
      await until(() => directoryCalls().last.queryParameters['search'] == 'Chirag', reason: 'the search');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(directoryCalls().last.queryParameters['group'], 'Param');
      expect(c.filteredStudents, isEmpty, reason: 'Chirag is in another group');

      c.searchFilterController.text = 'Asha';
      c.onSearchSubmitted('Asha');
      await until(() => directoryCalls().last.queryParameters['search'] == 'Asha', reason: 'the search');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.filteredStudents.map((s) => s['name']), ['Asha Patel']);
    });

    test('app requests are only from the group', () async {
      await signIn('leader');
      final c = await open();
      await until(() => c.pendingAppRequests.isNotEmpty, reason: 'app requests');
      expect(c.pendingAppRequests.map((r) => r['id']), [1]);
    });

    test('a student of another group is never opened directly', () async {
      await signIn('leader');
      final c = await open(args: {'id': 1050, 'name': 'Chirag Joshi'});
      expect(c.detail.value, isNull);
      expect(requests.where((r) => r.path.contains('/1050')), isEmpty);
    });

    test('a student of their own group opens directly', () async {
      await signIn('leader');
      final c = await open(args: {'id': 1043, 'name': 'Asha Patel'});
      await until(() => c.detail.value != null, reason: 'the student');
      expect(c.selectedStudent.value['id'].toString(), '1043');
      expect(c.openedWithDirectTarget.value, isTrue);
    });

    test('without a group nobody is shown', () async {
      leaderGroup = null;
      await signIn('leader');
      final c = Get.put(ScreenTimeDirectoryController());
      await until(() => c.leaderGroupMissing.value, reason: 'the missing group');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(c.allStudents, isEmpty);
      expect(directoryCalls(), hasLength(1), reason: 'only the group lookup');
      expect(c.pendingAppRequests, isEmpty);
    });
  });

  group('admin', () {
    test('still sees every student, page by page', () async {
      leaderGroup = null;
      await signIn('admin');
      final c = await open();
      expect(c.isLeaderView, isFalse);
      expect(c.allStudents, hasLength(3));
      expect(directoryCalls().first.queryParameters['limit'], ScreenTimeDirectoryController.pageSize);
      expect(directoryCalls().first.queryParameters.containsKey('group'), isFalse);
    });

    test('opens a student directly', () async {
      leaderGroup = null;
      await signIn('admin');
      Get.routing.args = {'id': 1050, 'name': 'Chirag Joshi'};
      final c = Get.put(ScreenTimeDirectoryController());
      await until(() => c.detail.value != null, reason: 'the student');
      expect(c.selectedStudent.value['id'].toString(), '1050');
    });
  });

  group('header', () {
    setUpAll(() async {
      await loadDeviceLikeFonts();
      await serveGoogleFontsAsAssets();
    });

    testWidgets('the back button closes the student list', (tester) async {
      await tester.runAsync(() => signIn('leader'));
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Get.put(ScreenTimeDirectoryController());
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StudentScreenTimeScreen()));
                },
                child: const Text('Open Screen Time'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open Screen Time'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Screen Time'), findsWidgets);
      expect(find.text('Param group'), findsOneWidget);

      // The centre of the button, where the title area used to swallow taps.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Open Screen Time'), findsOneWidget);
      expect(find.text('Param group'), findsNothing, reason: 'the screen closed');

      Get.delete<ScreenTimeDirectoryController>(force: true);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
