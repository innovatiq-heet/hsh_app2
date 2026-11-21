import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/repository/staff_users/staff_users_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/manage_users/controllers/manage_users_controller.dart';
import 'package:hsh_app2/features/manage_users/controllers/student_tags_controller.dart';
import 'package:hsh_app2/features/manage_users/views/manage_users_screen.dart';
import 'package:hsh_app2/features/manage_users/views/student_tags_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/test_fonts.dart';

/// Student Tags is its own screen; Manage Users is only staff accounts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  setUpAll(() async {
    await loadDeviceLikeFonts();
    await serveGoogleFontsAsAssets();
  });

  Future<void> signIn() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Admin'}),
    });
    final session = Get.put(SessionStore());
    await until(() => session.currentSession != null, reason: 'the session');
    api = FakeApi()..install();
    Get.put(TagsRepository());
    Get.put(StaffUsersRepository());
    api.on('GET /tags', {
      'success': true,
      'data': [
        {'id': 1, 'name': 'Regular', 'color': '#10b981', 'is_system': 1, 'student_count': 300},
        {'id': 12, 'name': 'Karyakarta', 'color': '#6366f1', 'is_system': 0, 'student_count': 14},
      ],
    });
    api.on('GET /admin/users', {
      'success': true,
      'data': [
        {
          'id': 3,
          'name': 'Ramesh Kumar',
          'phone_number': '9876543210',
          'role': 'complain-solver',
          'is_active': true,
          'created_at': '2026-10-20 10:00:00',
          'updated_at': '2026-10-20 10:00:00',
        },
      ],
      'roles': ['complain-solver', 'laundry-man'],
    });
    api.on('GET /complaint-categories', {'success': true, 'data': []});
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  tearDown(Get.reset);

  testWidgets('the Student Tags screen lists the tags and offers Add tag', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    Get.put(StudentTagsController());
    await tester.pumpWidget(const GetMaterialApp(home: StudentTagsScreen()));
    await settle(tester);

    expect(find.text('Student Tags'), findsWidgets);
    expect(find.text('Regular'), findsOneWidget);
    expect(find.text('Karyakarta'), findsOneWidget);
    expect(find.text('SYSTEM'), findsOneWidget);
    expect(find.text('Add tag'), findsOneWidget);
    expect(find.textContaining('Staff Users'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manage Users shows only staff accounts: no tab, no tags', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    Get.put(ManageUsersController());
    await tester.pumpWidget(const GetMaterialApp(home: ManageUsersScreen()));
    await settle(tester);

    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('Add user'), findsOneWidget);
    expect(find.textContaining('Student Tags'), findsNothing);
    expect(find.text('Add tag'), findsNothing);
    expect(find.text('Karyakarta'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
