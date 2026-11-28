import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/student_detail_controller.dart';
import 'package:hsh_app2/features/screentime/widgets/app_limit_sheet.dart';
import 'package:hsh_app2/features/screentime/widgets/app_usage_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

/// One app's daily time limit, set by the warden: the sheet saves it and
/// closes, a refused save keeps it open and rolls back, and the app list shows
/// the new limit at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> ruleRequests;
  late bool failRule;

  setUpAll(() async {
    await loadDeviceLikeFonts();
    await serveGoogleFontsAsAssets();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Warden'}),
    });
    Get.testMode = true;
    ruleRequests = [];
    failRule = false;
    Get.put(SessionStore());
    final api = ApiClient.create();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/screen-time/apps/rule') {
        ruleRequests.add(options);
        if (failRule) {
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 500, data: {'success': false, 'message': 'Server error'}),
          ));
          return;
        }
        handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'success': true}));
        return;
      }
      handler.resolve(Response(requestOptions: options, statusCode: 404, data: null));
    }));
    Get.put(api);
  });

  tearDown(Get.reset);

  /// A student whose phone used Instagram for 20 minutes today; the policy is
  /// loaded and has no app limits yet.
  StudentDetailController student() {
    final c = StudentDetailController(<String, dynamic>{'id': 903, 'name': 'Om', 'room': '306'});
    c.appBreakdown.assignAll([
      {'packageName': 'com.instagram.android', 'appName': 'Instagram', 'minutes': 20, 'dailyLimitMinutes': 0},
    ]);
    c.totalMinutesToday.value = 20;
    c.policyLoaded.value = true;
    return c;
  }

  Future<void> pumpWithSheet(WidgetTester tester, StudentDetailController c) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppLimitSheet.show(
              context,
              controller: c,
              packageName: 'com.instagram.android',
              appName: 'Instagram',
              currentLimit: c.appLimitFor('com.instagram.android'),
              currentUsage: c.usedTodayMinutes('com.instagram.android'),
            ),
            child: const Text('Limit'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Limit'));
    await tester.pumpAndSettle();
    expect(find.text('App time limit'), findsOneWidget);
    expect(find.text('Used today: 20m'), findsOneWidget);
  }

  /// Lets queued snackbars show and run out inside the test.
  Future<void> drainSnackbars(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String chip) async {
    await tester.tap(find.text(chip));
    await tester.pump();
    final button = find.text('Save time limit');
    await tester.ensureVisible(button);
    await tester.tap(button);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('saving a limit sends it, keeps it, and closes the sheet', (tester) async {
    final c = student();
    await pumpWithSheet(tester, c);

    await save(tester, '45m');

    expect(ruleRequests, hasLength(1));
    final body = ruleRequests.single.data as Map;
    expect(body['student_id'], '903');
    expect(body['package_name'], 'com.instagram.android');
    expect(body['daily_limit_minutes'], 45);
    expect(c.appLimits['com.instagram.android'], 45);
    expect(find.text('App time limit'), findsNothing, reason: 'the sheet closes after saving');

    await drainSnackbars(tester);
  });

  testWidgets('a refused save keeps the sheet open and the old limit', (tester) async {
    final c = student();
    failRule = true;
    await pumpWithSheet(tester, c);

    await save(tester, '45m');

    expect(ruleRequests, hasLength(1));
    expect(c.appLimits.containsKey('com.instagram.android'), isFalse, reason: 'rolled back');
    expect(find.text('App time limit'), findsOneWidget, reason: 'still open to try again');

    await drainSnackbars(tester);
  });

  testWidgets('the app list shows a new limit at once, not the row\'s stale 0', (tester) async {
    final c = student();
    tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: AppUsageCard(controller: c))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('45m limit'), findsNothing);

    expect(await tester.runAsync(() => c.setAppLimit('com.instagram.android', 'Instagram', 45)), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('45m limit'), findsOneWidget);

    expect(await tester.runAsync(() => c.setAppLimit('com.instagram.android', 'Instagram', 0)), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('45m limit'), findsNothing);
    expect(ruleRequests.last.data['daily_limit_minutes'], 0);

    await drainSnackbars(tester);
  });

  test('before the policy loads, the row\'s own limit is used', () {
    final c = StudentDetailController(<String, dynamic>{'id': 903, 'name': 'Om'});
    expect(c.appLimitFor('com.a', rowValue: 30), 30);
    c.policyLoaded.value = true;
    expect(c.appLimitFor('com.a', rowValue: 30), 0, reason: 'the policy has no limit for it');
    c.appLimits['com.a'] = 15;
    expect(c.appLimitFor('com.a', rowValue: 30), 15);
  });

  testWidgets('apps list avoids duplicate headers, protects system apps, and uses explicit Allowed/Blocked pills',
      (tester) async {
    final c = student();
    c.appBreakdown.add({
      'packageName': 'com.google.android.gms',
      'appName': 'Google Play services',
      'minutes': 3,
      'dailyLimitMinutes': 0,
    });
    c.totalMinutesToday.value = 23;

    tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: AppUsageCard(controller: c))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('App activity'), findsOneWidget);
    expect(find.text('Block presets'), findsOneWidget);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Blocked (0)'), findsOneWidget);
    expect(find.text('Limits (0)'), findsOneWidget);
    expect(find.textContaining('Used ('), findsNothing);

    // Core Android service shows System badge instead of an Allowed/Blocked toggle.
    expect(find.text('Google Play services'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // Regular app shows Allowed pill and toggles to Blocked cleanly on tap.
    expect(find.text('Allowed'), findsOneWidget);
    await tester.tap(find.text('Allowed'));
    await tester.pumpAndSettle();

    expect(ruleRequests.last.data['package_name'], 'com.instagram.android');
    expect(ruleRequests.last.data['is_blocked'], true);
    expect(find.text('Blocked (1)'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);

    await tester.tap(find.text('Blocked (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Google Play services'), findsNothing);

    await drainSnackbars(tester);
  });
}
