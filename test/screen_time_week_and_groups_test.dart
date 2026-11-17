import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_directory_controller.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:hsh_app2/features/screentime/widgets/student_directory_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The requests a student's Screen Time overview makes, its last-7-days
/// numbers for "Usage & trends", and the admin/warden group chips.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String dateBack(int days) {
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  group('with a fake API', () {
    const studentId = 903;
    late List<RequestOptions> requests;

    /// What `GET /screen-time/students` returns; the group tests replace it.
    late List<Map<String, dynamic>> directory;

    Map<String, dynamic> student(int id, String name, String group, {String room = '306'}) => {
          'id': id,
          'name': name,
          'room': room,
          'groupName': group,
          'totalScreenTimeMinutes': 40,
          'nightScreenTimeMinutes': 0,
          'isOnline': true,
          'isLocked': false,
        };

    Object? reply(RequestOptions o) {
      switch ('${o.method} ${o.path}') {
        case 'GET /screen-time/students':
          return {
            'success': true,
            'data': {
              'students': directory,
              'total': directory.length,
              'leaderGroupName': 'Param',
            },
          };
        case 'GET /screen-time/live/$studentId':
          return {
            'success': true,
            'data': {
              'studentId': studentId,
              'isOnline': true,
              'totalScreenTimeMinutes': 30,
              'appUsageBreakdown': [],
              'policy': null,
              'blockedPackages': [],
            },
          };
        // Like the real API: daily totals for the last days, whatever `date` asks.
        case 'GET /screen-time/history/$studentId':
          return {
            'success': true,
            'data': {
              'studentId': studentId,
              'records': [
                for (var i = 1; i <= 7; i++)
                  {'date': dateBack(i), 'total_screen_time_minutes': 60 + i, 'night_screen_time_minutes': 0},
              ],
            },
          };
        case 'GET /screen-time/policies/$studentId':
          return {
            'success': true,
            'data': {
              'policy': {'policy_version': 1, 'is_locked': 0, 'daily_limit_minutes': 0},
              'apps': [],
              'blockedPackages': [],
            },
          };
        case 'GET /geofence/policy':
          return {'id': 'default_curfew', 'startTime': '22:00', 'endTime': '06:00', 'isActive': true};
        case 'GET /screen-time/apps/requests':
          return {'success': true, 'data': []};
      }
      return null;
    }

    Future<void> until(bool Function() condition, {String reason = ''}) async {
      for (var i = 0; i < 300; i++) {
        if (condition()) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('timed out waiting for $reason');
    }

    Iterable<RequestOptions> history() => requests.where((r) => r.path == '/screen-time/history/$studentId');
    Iterable<RequestOptions> perDay() => history().where((r) => r.queryParameters.containsKey('date'));

    setUp(() {
      directory = [student(studentId, 'Om', 'Param')];
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
        final data = reply(options);
        handler.resolve(Response(requestOptions: options, statusCode: data == null ? 404 : 200, data: data));
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

    test('opening a student asks for past days at most once, and a refresh does not ask again', () async {
      Get.routing.args = {'id': studentId, 'name': 'Om', 'room': '306'};
      final directory = Get.put(ScreenTimeDirectoryController());
      await until(() => directory.detail.value != null, reason: 'the student controller');
      final c = directory.detail.value!;
      await until(() => c.historyRecords.isNotEmpty, reason: 'the history');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // The API has no per-day app breakdown, so one per-day request shows
      // that and the other six days are not asked for.
      expect(perDay().length, lessThanOrEqualTo(1));
      final historyCalls = history().length;

      // The periodic refresh: live status only.
      await c.fetchLiveStatus();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(history().length, historyCalls, reason: 'history is still fresh');

      // A past day whose total is known needs no request when picked.
      c.selectDate(dateBack(2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(history().length, historyCalls);
      expect(c.selectedDayTotalMinutes, 62);
    });

    test('the last 7 days come from the history and today from the live status', () async {
      Get.routing.args = {'id': studentId, 'name': 'Om', 'room': '306'};
      final directory = Get.put(ScreenTimeDirectoryController());
      await until(() => directory.detail.value != null, reason: 'the student controller');
      final c = directory.detail.value!;
      await until(() => c.historyRecords.isNotEmpty, reason: 'the history');

      final points = c.usagePoints(7);
      expect(points.map((p) => p['date']), [for (var i = 6; i >= 0; i--) dateBack(i)]);
      expect(points.map((p) => p['totalMinutes']), [66, 65, 64, 63, 62, 61, 30]);
    });

    group('group chips', () {
      setUp(() {
        directory = [
          student(1, 'Aarav', 'Param', room: '102'),
          student(2, 'Bhavin', 'Param', room: '203'),
          student(3, 'Chirag', 'Pavitra', room: '305'),
        ];
      });

      /// Shows the directory and lets its first load (role, then students) finish.
      Future<ScreenTimeDirectoryController> pumpDirectory(WidgetTester tester) async {
        final c = Get.put(ScreenTimeDirectoryController());
        await tester.pumpWidget(const GetMaterialApp(
          home: Scaffold(body: CustomScrollView(slivers: [StudentDirectoryView()])),
        ));
        for (var i = 0; i < 50 && c.allStudents.length < 3; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(c.allStudents.length, 3, reason: 'the directory loaded');
        return c;
      }

      /// Drops the screen and its controller so no refresh timer outlives the test.
      Future<void> dispose(WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox());
        Get.delete<ScreenTimeDirectoryController>(force: true);
        await tester.pump(const Duration(seconds: 1));
      }

      test('the count says "+" while more students are still to load', () {
        final c = ScreenTimeDirectoryController();
        c.allStudents.assignAll(directory);
        c.hasMoreStudents.value = true;
        expect(c.groupCountLabel('Param'), '2+');
        c.hasMoreStudents.value = false;
        expect(c.groupCountLabel('Param'), '2');
        expect(c.groupCountLabel('Pulkit'), '0');
      });

      testWidgets('an admin gets one-tap group chips that filter the list', (tester) async {
        final c = await pumpDirectory(tester);
        expect(c.currentRole.value, UserRole.admin);

        expect(find.text('All groups'), findsOneWidget);
        await tester.tap(find.text('Pavitra'));
        await tester.pump();
        expect(c.selectedGroup.value, 'Pavitra');
        expect(c.filteredStudents.map((s) => s['name']), ['Chirag']);
        final pavitraChip = find.ancestor(of: find.text('Pavitra'), matching: find.byType(InkWell)).first;
        expect(find.descendant(of: pavitraChip, matching: find.text('1')), findsOneWidget);

        await tester.tap(find.text('Pavitra'));
        await tester.pump();
        expect(c.selectedGroup.value, 'All');
        expect(c.filteredStudents.length, 3);
        await dispose(tester);
      });

      testWidgets('a leader is told which group is shown and gets no chips', (tester) async {
        final c = await pumpDirectory(tester);
        c.currentRole.value = UserRole.leader;
        await tester.pump();

        expect(find.text('All groups'), findsNothing);
        expect(find.text('Param group'), findsOneWidget);
        expect(find.text('You see only the students of your group.'), findsOneWidget);
        await dispose(tester);
      });
    });
  });
}
