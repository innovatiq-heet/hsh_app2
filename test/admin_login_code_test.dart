import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/constants/app_routes.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/network/repository/authentication/auth_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/auth/controllers/login_controller.dart';
import 'package:hsh_app2/features/auth/views/login_screen.dart';
import 'package:hsh_app2/features/splash/controllers/splash_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Admin sign-in needs the code the server sends on WhatsApp
/// (docs/PARENT_CONTROL_DOCS.md §5.7c). The app grants nothing by itself.
void main() {
  const adminUser = {'role': 'ADMIN', 'name': 'Super Admin', 'floor_id': 0};
  const codeNeeded = {
    'success': false,
    'requires_code': true,
    'code_type': 'admin',
    'message': 'Enter the code sent on WhatsApp to the numbers ending 7753 and 7261.',
  };

  late FakeApi api;

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(AuthRepository());
  });

  tearDown(Get.reset);

  Future<LoginController> openLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final controller = Get.put(LoginController());
    await tester.pumpWidget(GetMaterialApp(
      home: const LoginScreen(),
      getPages: [
        GetPage(name: Routes.operatorShell, page: () => const Scaffold(body: Text('Operator console'))),
      ],
    ));
    return controller;
  }

  /// Lets the request finish and any snackbar come and go.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.tap(find.text('Sign In'));
    await settle(tester);
  }

  testWidgets('an admin number asks for the WhatsApp code, then signs in with it', (tester) async {
    api.on('POST /auth/login', codeNeeded, status: 428);
    await openLogin(tester);
    await tester.enterText(find.byType(TextFormField).first, '+91 79849 07753');
    await tapSignIn(tester);

    expect(api.last('POST /auth/login').data['username'], 'admin');
    expect(api.last('POST /auth/login').data.containsKey('code'), isFalse);
    expect(find.text('Admin code'), findsOneWidget);
    expect(find.text('Send a new code'), findsOneWidget);
    expect(Get.find<SessionStore>().currentSession, isNull);

    api.on('POST /auth/login', {
      'success': true,
      'token': 'admin-token',
      'user': adminUser,
      'data': {'token': 'admin-token', 'user': adminUser},
    });
    // Moving to the code field must not hide it again.
    await tester.tap(find.byType(TextFormField).last);
    await tester.enterText(find.byType(TextFormField).last, '483920');
    await tapSignIn(tester);

    expect(api.last('POST /auth/login').data['code'], '483920');
    final session = Get.find<SessionStore>().currentSession!;
    expect(session.role, UserRole.admin);
    expect(session.phone, '7984907753');
    expect(find.text('Operator console'), findsOneWidget);
  });

  testWidgets('"Send a new code" asks again without the old code', (tester) async {
    api.on('POST /auth/login', codeNeeded, status: 428);
    await openLogin(tester);
    await tester.enterText(find.byType(TextFormField).first, '7984907753');
    await tapSignIn(tester);
    await tester.enterText(find.byType(TextFormField).last, '111111');

    await tester.tap(find.text('Send a new code'));
    await settle(tester);

    expect(api.called('POST /auth/login').length, 2);
    expect(api.last('POST /auth/login').data.containsKey('code'), isFalse);
  });

  test('startup opens the console only for a token issued after the code', () {
    String jwt(Map<String, Object> claims) =>
        'h.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.s';
    const check = SplashController.isCodeVerifiedAdminToken;

    expect(check(jwt({'id': 9999, 'role': 'admin', 'otp': true})), isTrue);
    expect(check(jwt({'id': 9999, 'role': 'admin'})), isFalse);
    // What earlier app builds made up when the server refused them.
    expect(check('admin_session_1795750000000'), isFalse);
    expect(check('a.%%%.c'), isFalse);
  });

  testWidgets('a server failure gives no admin session', (tester) async {
    api.on('POST /auth/login', {'success': false, 'message': 'Server error'}, status: 500);
    final controller = await openLogin(tester);
    await tester.enterText(find.byType(TextFormField).first, '7984907753');
    await tapSignIn(tester);

    expect(Get.find<SessionStore>().currentSession, isNull);
    expect(controller.errorMessage.value, isNotEmpty);
    expect(find.text('Operator console'), findsNothing);
  });
}
