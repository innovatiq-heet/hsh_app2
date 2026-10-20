import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/repository/authentication/auth_repository.dart';
import 'package:hsh_app2/core/network/repository/complaints/complaints_repository.dart';
import 'package:hsh_app2/core/network/repository/staff_users/staff_users_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/complaints/controllers/add_complaint_controller.dart';
import 'package:hsh_app2/features/complaints/controllers/complaint_admin_detail_controller.dart';
import 'package:hsh_app2/features/complaints/controllers/complaint_detail_controller.dart';
import 'package:hsh_app2/features/complaints/controllers/complaint_home_controller.dart';
import 'package:hsh_app2/features/complaints/controllers/complaint_orders_controller.dart';
import 'package:hsh_app2/features/complaints/controllers/complaints_controller.dart';
import 'package:hsh_app2/features/complaints/views/add_complaint_screen.dart';
import 'package:hsh_app2/features/complaints/views/complaint_admin_detail_screen.dart';
import 'package:hsh_app2/features/complaints/views/complaint_detail_screen.dart';
import 'package:hsh_app2/features/complaints/views/complaint_home_screen.dart';
import 'package:hsh_app2/features/complaints/views/complaint_orders_screen.dart';
import 'package:hsh_app2/features/complaints/views/complaints_screen.dart';
import 'package:hsh_app2/features/manage_users/controllers/manage_users_controller.dart';
import 'package:hsh_app2/features/manage_users/views/manage_users_screen.dart';
import 'package:hsh_app2/features/manage_users/widgets/staff_user_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';
import '../support/test_fonts.dart';

/// Renders the complaint and Manage Users screens at phone size with data,
/// so layout overflows and GetX misuse fail here rather than on a device.
void main() {
  late FakeApi api;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadDeviceLikeFonts();
  });

  final complaint = {
    'id': 12,
    'room_id': '101',
    'category_id': 1,
    'category': 'Electrical',
    'item_id': 5,
    'item': 'Switch Board',
    'item_code': 'SWITCH_BOARD',
    'comment': 'Sparks when the fan switch is turned on, please check soon.',
    'image_url': null,
    'status': 'IN_PROGRESS',
    'created_at': '2026-10-20 14:05:11',
    'updated_at': '2026-10-20 15:00:00',
    'student': {'id': 42, 'name': 'Rahul Bhaveshbhai Patel', 'student_code': '0768'},
  };

  void signIn(String role) {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_session': jsonEncode({'role': role, 'token': 'test-token', 'name': 'Test', 'room': '101'}),
    });
    Get.put(SessionStore());
  }

  setUp(() {
    Get.testMode = true;
    api = FakeApi();
    api.on('GET /complaint-categories', {
      'success': true,
      'data': [
        for (final (i, n) in ['Electrical', 'Carpentry', 'Housekeeping', 'Plumbing', 'Other'].indexed)
          {'id': i + 1, 'name': n},
      ],
    });
    api.on('GET /complaint-items', {
      'success': true,
      'data': [
        for (final (i, n) in ['Fan', 'Light', 'Geyser', 'Switch Board', 'AC'].indexed)
          {'id': i + 1, 'categoryId': 1, 'name': n, 'code': n.toUpperCase()},
      ],
    });
    api.on('GET /auth/me', {
      'success': true,
      'data': {'id': 42, 'name': 'Rahul', 'role': 'student', 'room': '101', 'room_number': '101'},
    });
    api.on('GET /complaints/my', {'success': true, 'data': [complaint, complaint]});
    api.on('GET /complaints/12', {'success': true, 'data': complaint});
    api.on('GET /admin/complaints', {'success': true, 'data': [complaint, complaint]});
    api.on('GET /admin/users', {
      'success': true,
      'data': [
        {'id': 3, 'name': 'Ramesh Kumar Prajapati', 'phone_number': '9876543210', 'role': 'complain-solver', 'is_active': true},
        {'id': 4, 'name': 'Suresh', 'phone_number': '9876500000', 'role': 'laundry-man', 'is_active': false},
      ],
      'roles': ['complain-solver', 'laundry-man'],
    });
  });

  tearDown(() {
    Get.reset();
    Get.routing.args = null;
  });

  /// Creates the controller outside the test's fake clock (so its HTTP
  /// calls complete), waits until [ready], then pumps [screen] on a 360×780
  /// phone.
  Future<T> show<T extends Object>(
    WidgetTester tester,
    T Function() create,
    bool Function(T) ready,
    Widget screen,
  ) async {
    final controller = (await tester.runAsync(() async {
      final c = create();
      await until(() => ready(c), reason: 'screen data');
      return c;
    }))!;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: screen));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    return controller;
  }

  void registerRepos() {
    api.install();
    Get.put(AuthRepository());
    Get.put(ComplaintsRepository());
    Get.put(StaffUsersRepository());
  }

  testWidgets('student: My Complaints', (tester) async {
    signIn('student');
    registerRepos();
    await show(tester, () => Get.put(ComplaintsController()), (c) => !c.isLoading.value, const ComplaintsScreen());

    expect(find.text('My complaints'), findsOneWidget);
    expect(find.text('Switch Board'), findsWidgets);
    expect(find.text('New complaint'), findsOneWidget);
  });

  testWidgets('student: new complaint with items shown', (tester) async {
    signIn('student');
    registerRepos();
    final c = await show(tester, () => Get.put(AddComplaintController()), (c) => !c.isLoading.value, const AddComplaintScreen());
    await tester.runAsync(() => c.selectCategory(c.categories.first));
    await tester.pump();

    expect(find.text('Housekeeping'), findsOneWidget);
    expect(find.text('Switch Board'), findsOneWidget);
    expect(find.text('101'), findsOneWidget);
  });

  testWidgets('student: complaint detail', (tester) async {
    signIn('student');
    registerRepos();
    Get.routing.args = '12';
    await show(tester, () => Get.put(ComplaintDetailController()), (c) => !c.isLoading.value, const ComplaintDetailScreen());

    expect(find.text('Resolution progress'), findsOneWidget);
    expect(find.text('Room Number'), findsOneWidget);
  });

  testWidgets('solver: desk', (tester) async {
    signIn('complain-solver');
    registerRepos();
    await show(
      tester,
      () => Get.put(ComplainOrdersController()),
      (c) => !c.isLoading.value && c.categories.isNotEmpty,
      const ComplainOrdersScreen(),
    );

    expect(find.text('Complaints Desk'), findsWidgets);
    expect(find.textContaining('Rahul Bhaveshbhai Patel'), findsWidgets);
  });

  testWidgets('solver: complaint review', (tester) async {
    signIn('complain-solver');
    registerRepos();
    Get.routing.args = '12';
    await show(tester, () => Get.put(ComplainAdminDetailController()), (c) => !c.isLoading.value, const ComplainAdminDetailScreen());

    expect(find.text('Update status'), findsOneWidget);
    expect(find.text('In progress'), findsWidgets);
  });

  testWidgets('solver: overview', (tester) async {
    signIn('complain-solver');
    registerRepos();
    await show(tester, () => Get.put(ComplainHomeController()), (c) => !c.isLoading.value, const Scaffold(body: ComplainHomeScreen()));

    expect(find.text('Queue Breakdown'), findsOneWidget);
  });

  testWidgets('admin: manage users and the form sheet', (tester) async {
    signIn('admin');
    registerRepos();
    final c = await show(tester, () => Get.put(ManageUsersController()), (c) => !c.isLoading.value, const ManageUsersScreen());

    expect(find.text('Ramesh Kumar Prajapati'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);

    StaffUserFormSheet.show(user: c.users.first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Edit user'), findsOneWidget);
    expect(find.text('Complaint Solver'), findsWidgets);

    // Close the sheet so its animation is finished before teardown.
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Edit user'), findsNothing);
  });

  testWidgets('a failed load shows a way back', (tester) async {
    signIn('student');
    registerRepos();
    api.on('GET /complaints/12', {'success': false, 'message': 'Complaint not found'}, status: 404);
    Get.routing.args = '12';
    await show(tester, () => Get.put(ComplaintDetailController()), (c) => !c.isLoading.value, const ComplaintDetailScreen());

    expect(find.text('Complaint not found'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
