import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/repository/staff_users/staff_users_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/core/utils/validators.dart';
import 'package:hsh_app2/features/manage_users/controllers/manage_users_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Admin → Manage Users against `/admin/users`, with HTTP faked offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;
  late ManageUsersController controller;

  Map<String, dynamic> userJson({int id = 3, String name = 'Ramesh', bool active = true}) => {
        'id': id,
        'name': name,
        'phone_number': '9876543210',
        'role': 'complain-solver',
        'is_active': active,
        'created_at': '2026-10-20 10:00:00',
        'updated_at': '2026-10-20 10:00:00',
      };

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'admin-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
    Get.put(StaffUsersRepository());
    api.on('GET /admin/users', {
      'success': true,
      'data': [userJson()],
      'roles': ['complain-solver', 'laundry-man'],
    });
    controller = Get.put(ManageUsersController());
    await until(() => !controller.isLoading.value, reason: 'users load');
  });

  tearDown(Get.reset);

  test('lists users and the roles for the dropdown', () {
    expect(controller.users.single.name, 'Ramesh');
    expect(controller.users.single.isActive, isTrue);
    expect(controller.users.single.roleLabel, 'Complaint Solver');
    expect(controller.roles, ['complain-solver', 'laundry-man']);
  });

  test('create sends name, normalized number and role, and adds the user', () async {
    api.on(
      'POST /admin/users',
      {'success': true, 'message': 'User created successfully', 'data': userJson(id: 4, name: 'Suresh')},
      status: 201,
    );

    final error = await controller.create(name: ' Suresh ', phone: '+91 98765 43210', role: 'laundry-man');

    expect(error, isNull);
    expect(api.last('POST /admin/users').data, {
      'name': 'Suresh',
      'phone_number': '9876543210',
      'role': 'laundry-man',
    });
    expect(controller.users.first.id, 4);
  });

  test('a 409 message is returned as-is for the form', () async {
    const message = 'This number is already used by a student (Rahul Patel).';
    api.on('POST /admin/users', {'success': false, 'message': message}, status: 409);

    final error = await controller.create(name: 'Suresh', phone: '9876543210', role: 'laundry-man');

    expect(error, message);
    expect(controller.users, hasLength(1));
  });

  test('edit sends only the changed fields', () async {
    api.on('PUT /admin/users/3', {'success': true, 'data': userJson(name: 'Ramesh K')});

    final error = await controller.edit(
      controller.users.single,
      name: 'Ramesh K',
      phone: '9876543210',
      role: 'complain-solver',
    );

    expect(error, isNull);
    expect(api.last('PUT /admin/users/3').data, {'name': 'Ramesh K'});
    expect(controller.users.single.name, 'Ramesh K');
  });

  test('edit with no changes makes no request', () async {
    final error = await controller.edit(
      controller.users.single,
      name: 'Ramesh',
      phone: '+91 98765 43210',
      role: 'complain-solver',
    );

    expect(error, isNull);
    expect(api.called('PUT /admin/users/3'), isEmpty);
  });

  test('switching a user off sends a real boolean', () async {
    api.on('PUT /admin/users/3', {'success': true, 'data': userJson(active: false)});

    await controller.setActive(controller.users.single, false);

    expect(api.last('PUT /admin/users/3').data, {'is_active': false});
    expect(controller.users.single.isActive, isFalse);
  });

  test('a failed switch is rolled back', () async {
    api.on('PUT /admin/users/3', {'success': false, 'message': 'Server error'}, status: 500);

    await controller.setActive(controller.users.single, false);

    expect(controller.users.single.isActive, isTrue);
    expect(controller.busyIds, isEmpty);
  });

  test('delete removes the user', () async {
    api.on('DELETE /admin/users/3', {'success': true, 'message': 'User deleted successfully'});

    await controller.delete(controller.users.single);

    expect(controller.users, isEmpty);
  });

  test('a 404 on delete keeps the row', () async {
    api.on('DELETE /admin/users/3', {'success': false, 'message': 'User not found'}, status: 404);

    await controller.delete(controller.users.single);

    expect(controller.users, hasLength(1));
  });

  test('mobile numbers are validated the way the API does', () {
    expect(Validators.normalizeMobile('9876543210'), '9876543210');
    expect(Validators.normalizeMobile('+91 98765 43210'), '9876543210');
    expect(Validators.normalizeMobile('09876543210'), '9876543210');
    expect(Validators.normalizeMobile('5876543210'), isNull, reason: 'must start 6-9');
    expect(Validators.normalizeMobile('98765'), isNull);
    expect(Validators.mobile(''), isNotNull);
    expect(Validators.mobile('98765 43210'), isNull);
    expect(ManageUsersController.validateName('x' * 101), isNotNull);
    expect(ManageUsersController.validateName('  '), isNotNull);
  });
}
