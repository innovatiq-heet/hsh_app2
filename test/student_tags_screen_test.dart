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
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';
import 'package:hsh_app2/features/phonebook/widgets/alpha_scroll_rail.dart';
import 'package:hsh_app2/features/phonebook/widgets/student_tag_sheet.dart';
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

  testWidgets('tapping a system tag opens a strictly read-only student count & member list', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    api.on('GET /tags/1/students', {
      'success': true,
      'data': {
        'tag': {'id': 1, 'name': 'Regular', 'color': '#10b981', 'is_system': 1, 'student_count': 2},
        'student_count': 2,
        'students': [
          {'id': 101, 'student_code': '101', 'name': 'Aarav Patel', 'floor_id': 1, 'room_number': '101', 'group_name': 'Param', 'is_active': 1},
          {'id': 102, 'student_code': '102', 'name': 'Bhavik Shah', 'floor_id': 2, 'room_number': '205', 'group_name': 'Pavitra', 'is_active': 1},
        ],
      },
    });
    Get.put(StudentTagsController());
    await tester.pumpWidget(const GetMaterialApp(home: StudentTagsScreen()));
    await settle(tester);

    // Tap the Regular system tag card.
    await tester.tap(find.text('Regular'));
    await settle(tester);

    // Shows read-only header, total count, and member students.
    expect(find.text('SYSTEM TAG · VIEW ONLY'), findsOneWidget);
    expect(find.text('2 students'), findsOneWidget);
    expect(find.text('Auto-calculated'), findsOneWidget);
    expect(find.text('Aarav Patel'), findsOneWidget);
    expect(find.text('Bhavik Shah'), findsOneWidget);

    // Strictly no edit/assign/select/manage controls anywhere.
    expect(find.byTooltip('Edit tag'), findsNothing);
    expect(find.text('Assign'), findsNothing);
    expect(find.text('Assigned'), findsNothing);
    expect(find.text('Select students'), findsNothing);
    expect(find.text('Manage'), findsNothing);
    expect(find.text('Manage tags'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StudentTagSheet locks assigned system tags, hides unassigned ones, and removes inline tag text editing',
      (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    api.on('GET /tags', {
      'success': true,
      'data': [
        {'id': 1, 'name': 'Regular', 'color': '#10b981', 'is_system': 1, 'student_count': 300},
        {'id': 2, 'name': 'Irregular', 'color': '#f59e0b', 'is_system': 1, 'student_count': 20},
        {'id': 3, 'name': 'iPhone', 'color': '#0284c7', 'is_system': 1, 'student_count': 45},
        {'id': 12, 'name': 'Karyakarta', 'color': '#6366f1', 'is_system': 0, 'student_count': 14},
      ],
    });
    api.on('GET /tags/student/101', {
      'success': true,
      'data': {
        'student_id': 101,
        'system_tag': {'id': 1, 'name': 'Regular', 'color': '#10b981', 'is_system': 1},
        'assigned_tags': [],
        'max_allowed': 99,
      },
    });
    api.on('POST /tags/student/101', {'success': true, 'data': {'assigned_tag_ids': [12]}});

    const student = PhonebookStudent(
      id: '101',
      studentId: '101',
      name: 'Aarav Patel',
      enrollmentNumber: 'E101',
      department: 'CS',
      batch: '2024',
      room: '101',
      phones: [],
    );

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: StudentTagSheet(student: student, studentId: 101),
        ),
      ),
    );
    await settle(tester);

    // Assigned system tag appears locked; unassigned system tags are not shown.
    expect(find.text('System tags (locked)'), findsOneWidget);
    expect(find.text('Regular'), findsOneWidget);
    expect(find.text('Irregular'), findsNothing);
    expect(find.text('iPhone'), findsNothing);
    expect(find.text('(System)'), findsNothing);

    // No inline edit-tag pencil icon on custom tag pills.
    expect(find.text('Karyakarta'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsNothing);

    // Custom tag still assigns on tap.
    await tester.tap(find.text('Karyakarta'));
    await settle(tester);
    expect(api.called('POST /tags/student/101'), hasLength(1));

    // Drain any snackbar timers cleanly.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('student list in tag section shows AlphaScrollRail on open and switches to A-Z when slid',
      (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    api.on('GET /tags/1/students', {
      'success': true,
      'data': {
        'tag': {'id': 1, 'name': 'Regular', 'color': '#10b981', 'is_system': 1, 'student_count': 3},
        'student_count': 3,
        'students': [
          {'id': 101, 'student_code': '101', 'name': 'Zubin Mehta', 'floor_id': 1, 'room_number': '101', 'group_name': 'Param', 'is_active': 1},
          {'id': 102, 'student_code': '102', 'name': 'Aarav Patel', 'floor_id': 1, 'room_number': '102', 'group_name': 'Param', 'is_active': 1},
          {'id': 103, 'student_code': '103', 'name': 'Milan Shah', 'floor_id': 2, 'room_number': '205', 'group_name': 'Pavitra', 'is_active': 1},
        ],
      },
    });
    Get.put(StudentTagsController());
    await tester.pumpWidget(const GetMaterialApp(home: StudentTagsScreen()));
    await settle(tester);

    // Open the tag's student list (defaults to Room-wise sort).
    await tester.tap(find.text('Regular'));
    await settle(tester);

    // Slider rail is shown immediately without manually switching sort mode.
    final rail = find.byType(AlphaScrollRail);
    expect(rail, findsOneWidget);
    final studentsTab = find.byKey(const ValueKey('rail-students'));
    expect(studentsTab, findsOneWidget);

    // First tap opens the letter strip; sliding/tapping a letter switches to Name A-Z.
    await tester.tap(studentsTab);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final topRight = tester.getTopRight(studentsTab);
    final x = topRight.dx - 14;
    await tester.tapAt(Offset(x, topRight.dy + 15.5));
    await settle(tester);

    expect(find.text('Students starting with "A"'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let AlphaScrollRail's auto-collapse timer finish cleanly.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
