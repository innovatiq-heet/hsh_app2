import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/constants/app_routes.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/services/push_notification_service.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tapping a Screen Time push. The payloads are the ones hsh_api sends: their
/// `route` is the server's name for the page, not an app route.
void main() {
  const alert = {
    'type': 'screen_time_alert',
    'alert_type': 'code_redeemed',
    'student_id': '42',
    'student_name': 'Asha',
    'route': '/student-screen-time',
  };
  const appRequest = {
    'type': 'app_request',
    'student_id': '42',
    'student_name': 'Asha',
    'route': '/student-screen-time',
  };

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put(SessionStore());
  });

  tearDown(Get.reset);

  Future<void> tapAs(
    WidgetTester tester,
    UserRole role,
    Map<String, dynamic> payload,
  ) async {
    await Get.find<SessionStore>().saveSession(
      token: 'token',
      role: role,
      email: '',
      name: 'Someone',
      room: '101',
    );
    await tester.pumpWidget(GetMaterialApp(
      initialRoute: '/start',
      getPages: [
        GetPage(name: '/start', page: () => const Text('Start')),
        GetPage(
          name: Routes.studentScreenTime,
          page: () => Text('Screen Time of ${(Get.arguments as Map)['student_id']}'),
        ),
        GetPage(name: Routes.studentHome, page: () => const Text('Home')),
        GetPage(name: '/elsewhere', page: () => const Text('Elsewhere')),
      ],
    ));
    await tester.pumpAndSettle();
    PushNotificationService().openPayload(payload);
    await tester.pumpAndSettle();
  }

  for (final role in [UserRole.admin, UserRole.warden, UserRole.leader]) {
    testWidgets('${role.name}: a screen-time alert opens that student', (tester) async {
      await tapAs(tester, role, alert);
      expect(find.text('Screen Time of 42'), findsOneWidget);
    });
  }

  testWidgets('an app request opens that student', (tester) async {
    await tapAs(tester, UserRole.admin, appRequest);
    expect(find.text('Screen Time of 42'), findsOneWidget);
  });

  testWidgets('the alert type alone, without a route, opens it too', (tester) async {
    await tapAs(tester, UserRole.admin, {'type': 'screen_time_alert', 'student_id': '42'});
    expect(find.text('Screen Time of 42'), findsOneWidget);
  });

  testWidgets('a student never lands on the Screen Time page', (tester) async {
    await tapAs(tester, UserRole.student, alert);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('any other route is opened as sent', (tester) async {
    await tapAs(tester, UserRole.admin, {'route': '/elsewhere'});
    expect(find.text('Elsewhere'), findsOneWidget);
  });
}
