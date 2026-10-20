import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/constants/app_routes.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/network/repository/authentication/auth_repository.dart';
import 'package:hsh_app2/core/network/request/authentication/login_request.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Staff created in Manage Users (complain-solver, laundry-man) sign in with
/// their number alone and are signed out when deactivated.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const staffUser = {
    'role': 'complain-solver',
    'id': 3,
    'staff_id': 3,
    'name': 'Ramesh',
    'phone_number': '9876543210',
  };

  late FakeApi api;

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    Get.put(SessionStore());
    api = FakeApi();
  });

  tearDown(Get.reset);

  test('number login maps a staff user to its role, not to alumni', () async {
    api.install();
    Get.put(AuthRepository());
    api.on('POST /auth/login', {
      'success': true,
      'status': 'ok',
      'token': 'staff-token',
      'user': staffUser,
      'data': {'token': 'staff-token', 'user': staffUser},
    });

    final session = await Get.find<AuthRepository>().login(
      const LoginRequest(studentId: '9876543210'),
    );

    expect(api.last('POST /auth/login').data['username'], '9876543210');
    expect(session.role, UserRole.complainsolver);
    expect(session.token, 'staff-token');
    expect(session.phone, '9876543210');
    expect(session.isAlumni, isFalse, reason: 'staff have no room; that is not alumni');
    expect(session.room, isEmpty);
  });

  test('a saved staff session is not alumni, even if flagged as one', () async {
    // The room-based alumni check reads an empty room as alumni; callers
    // have passed that through for staff.
    await Get.find<SessionStore>().saveSession(
      token: 'staff-token',
      role: UserRole.laundry,
      email: '',
      name: 'Suresh',
      room: '',
      isAlumni: true,
    );

    final session = Get.find<SessionStore>().session!;
    expect(session.role, UserRole.laundry);
    expect(session.isAlumni, isFalse);
    expect(session.room, isEmpty);
  });

  group('401 handling', () {
    late ApiClient client;

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: '/desk',
        getPages: [
          GetPage(name: '/desk', page: () => const Scaffold(body: Text('desk'))),
          GetPage(name: Routes.login, page: () => const Scaffold(body: Text('login'))),
        ],
      ));
      await Get.find<SessionStore>().saveSession(
        token: 'staff-token',
        role: UserRole.complainsolver,
        email: '',
        name: 'Ramesh',
      );
      client = api.install();
    }

    Future<void> request(WidgetTester tester) async {
      await tester.runAsync(() async {
        try {
          await client.dio.get('/admin/complaints');
        } catch (_) {}
      });
      await tester.pumpAndSettle();
    }

    testWidgets('a deactivated staff user is signed out', (tester) async {
      await pumpApp(tester);
      api.on('GET /admin/complaints', {'success': false, 'message': 'Staff account not found or inactive.'}, status: 401);

      await request(tester);

      expect(find.text('login'), findsOneWidget);
      expect(Get.find<SessionStore>().currentToken, isNull);
    });

    testWidgets('an inactive student record is shown in place, not signed out', (tester) async {
      await pumpApp(tester);
      api.on('GET /admin/complaints', {'success': false, 'message': 'Student account not found or inactive.'}, status: 401);

      await request(tester);

      expect(find.text('desk'), findsOneWidget);
      expect(Get.find<SessionStore>().currentToken, 'staff-token');
    });
  });

  test('both staff roles are recognised from the API values', () {
    expect(UserRoleX.fromApi('complain-solver'), UserRole.complainsolver);
    expect(UserRoleX.fromApi('laundry-man'), UserRole.laundry);
    expect(UserRole.complainsolver.canSolveComplaints, isTrue);
    expect(UserRole.laundry.canSolveComplaints, isFalse);
  });
}
