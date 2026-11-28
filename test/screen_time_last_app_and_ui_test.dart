import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_directory_controller.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_utils.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:hsh_app2/features/screentime/curfew/models.dart';
import 'package:hsh_app2/features/screentime/widgets/live_status_card.dart';
import 'package:hsh_app2/features/screentime/widgets/student_directory_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadDeviceLikeFonts);

  group('lastUsedAppOf helper', () {
    test('extracts camelCase and snake_case fields and ignores idle currentApp', () {
      final info = lastUsedAppOf({
        'currentApp': 'Idle',
        'lastUsedApp': 'YouTube',
        'lastUsedAppPackage': 'com.google.android.youtube',
        'lastUsedAppMinutesAgo': 12,
      });
      expect(info, isNotNull);
      expect(info!.appName, 'YouTube');
      expect(info.packageName, 'com.google.android.youtube');
      expect(info.minutesAgo, 12);
      expect(formatLastUsedAgo(info.minutesAgo, info.usedAt), '12m ago');

      final snake = lastUsedAppOf({
        'current_app': 'Standby',
        'last_used_app': 'WhatsApp',
        'last_used_app_package': 'com.whatsapp',
        'last_used_app_minutes_ago': 125,
      });
      expect(snake, isNotNull);
      expect(snake!.appName, 'WhatsApp');
      expect(formatLastUsedAgo(snake.minutesAgo, snake.usedAt), '2h ago');

      expect(lastUsedAppOf({'currentApp': 'Idle'}), isNull);
    });

    test('StudentSummary parses lastUsedApp and recentApps', () {
      final summary = StudentSummary({
        'student': {'id': 1, 'name': 'Test Student', 'room_number': '415'},
        'status': {
          'connection_status': 'quiet',
          'is_screen_on': false,
          'current_app': null,
          'last_used_app': 'Instagram',
          'last_used_app_package': 'com.instagram.android',
          'last_used_app_minutes_ago': 18,
        },
        'rules': [],
        'sessions': [],
        'today': {'total_minutes': 25, 'session_use_minutes': 0},
        'usage': {
          'daily_avg_minutes': 20,
          'previous_daily_avg_minutes': 15,
          'session_use_minutes': 0,
          'days': [],
          'top_apps': [],
          'recent_apps': [
            {
              'package_name': 'com.instagram.android',
              'app_name': 'Instagram',
              'minutes': 14,
              'minutes_ago': 18,
            },
          ],
        },
        'problems': {'attention': [], 'block_attempts_by_reason': {}, 'recent_alerts': []},
      });
      expect(summary.lastUsedApp, 'Instagram');
      expect(summary.lastUsedAppPackage, 'com.instagram.android');
      expect(summary.lastUsedAppMinutesAgo, 18);
      expect(summary.recentApps, hasLength(1));
      expect(summary.recentApps.first.appName, 'Instagram');
      expect(summary.recentApps.first.minutes, 14);
    });
  });

  group('Screen Time directory & live status UI', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'test-token', 'name': 'Warden'}),
      });
      Get.testMode = true;
      Get.put(SessionStore());

      final api = ApiClient.create();
      api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        final route = '${options.method} ${options.path}';
        if (route.startsWith('GET /screen-time/students')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'students': [
                  {
                    'id': 415,
                    'name': 'Shreemad Rajeshkumar Patel',
                    'room': '415',
                    'isOnline': true,
                    'isScreenOn': false,
                    'currentApp': '',
                    'lastUsedApp': 'YouTube',
                    'lastUsedAppPackage': 'com.google.android.youtube',
                    'lastUsedAppMinutesAgo': 12,
                    'batteryLevel': 59,
                    'totalScreenTimeMinutes': 45,
                    'nightScreenTimeMinutes': 0,
                    'compliance': {'deviceAdminActive': false},
                  },
                ],
                'total': 1,
                'onlineCount': 1,
                'offlineCount': 0,
                'lockedCount': 0,
                'connectionCounts': {'online': 1, 'quiet': 0, 'offline': 0},
              },
            },
          ));
          return;
        }
        if (route == 'GET /geofence/policy') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'id': 'default', 'startTime': '19:09', 'endTime': '19:15', 'isActive': false},
          ));
          return;
        }
        if (route == 'GET /screen-time/sessions') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
          return;
        }
        if (route == 'GET /screen-time/apps/requests') {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': []},
          ));
          return;
        }
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': {}},
        ));
      }));
      Get.put(api, permanent: true);
    });

    tearDown(Get.reset);

    testWidgets('Directory renders clean header, geofence row, and last used app badge without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      Get.put(ScreenTimeDirectoryController());
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: StudentDirectoryView(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Curfew sessions'), findsOneWidget);
      expect(find.text('Campus geofence'), findsOneWidget);
      expect(find.text('Rm 415'), findsOneWidget);
      expect(find.text('Last: YouTube · 12m ago'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      Get.delete<ScreenTimeDirectoryController>(force: true);
    });

    testWidgets('LiveStatusCard displays last used app and recent apps in Standby', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final detail = Get.put(StudentDetailController(<String, dynamic>{
        'id': 415,
        'name': 'Shreemad',
        'room': '415',
        'isOnline': true,
        'isScreenOn': false,
        'currentApp': 'Idle',
        'lastUsedApp': 'YouTube',
        'lastUsedAppPackage': 'com.google.android.youtube',
        'lastUsedAppMinutesAgo': 12,
      }));
      detail.recentApps.assignAll([
        {
          'packageName': 'com.google.android.youtube',
          'appName': 'YouTube',
          'minutes': 25,
          'minutesAgo': 12,
        },
        {
          'packageName': 'com.whatsapp',
          'appName': 'WhatsApp',
          'minutes': 8,
          'minutesAgo': 35,
        },
      ]);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: LiveStatusCard(controller: detail),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Last used app'), findsOneWidget);
      expect(find.text('YouTube · 12m ago'), findsOneWidget);
      expect(find.text('Recently used'), findsOneWidget);
      expect(find.text('YouTube · 25m · 12m ago'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      Get.delete<StudentDetailController>(force: true);
      await tester.pump();
    });
  });
}
