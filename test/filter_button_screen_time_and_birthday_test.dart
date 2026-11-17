import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/models/birthday/birthday_models.dart';
import 'package:hsh_app2/core/network/api_client.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/birthday/controllers/admin_birthday_controller.dart';
import 'package:hsh_app2/features/birthday/views/admin_birthday_screen.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_directory_controller.dart';
import 'package:hsh_app2/features/screentime/widgets/student_directory_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
          data: {'success': true, 'data': {'students': [], 'total': 0}},
        ));
        return;
      }
      if (route == 'GET /geofence/policy') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'id': 'default', 'startTime': '22:00', 'endTime': '06:00', 'isActive': true},
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
      if (route == 'GET /whatsapp/birthday') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'status': 'success',
            'data': {
              'config': {
                'isEnabled': true,
                'sendTime': '09:00',
                'targetAudience': 'all',
                'preferWhatsAppNumber': true,
              },
              'todaysBirthdays': [],
              'tomorrowsBirthdays': [],
              'recentLogs': [],
              'isWhatsAppConnected': true,
              'senderPhone': '9876543210',
            },
          },
        ));
        return;
      }
      if (route == 'GET /whatsapp/status') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'status': 'success',
            'data': {'status': 'open'},
          },
        ));
        return;
      }
      if (route.startsWith('GET /whatsapp/birthday/all-students')) {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'status': 'success', 'data': []},
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true},
      ));
    }));
    Get.put(api);
  });

  tearDown(() {
    if (Get.isRegistered<ScreenTimeDirectoryController>()) {
      Get.delete<ScreenTimeDirectoryController>(force: true);
    }
    if (Get.isRegistered<AdminBirthdayController>()) {
      Get.delete<AdminBirthdayController>(force: true);
    }
    Get.reset();
  });

  group('Screen Time Filter Button & Logic', () {
    late ScreenTimeDirectoryController controller;

    setUp(() {
      controller = ScreenTimeDirectoryController();
      controller.allStudents.assignAll([
        {
          'id': '101',
          'name': 'Aarav Patel',
          'room': '102',
          'phone': '9876543210',
          'aadhar': '123456789012',
          'groupName': 'Param',
          'status': 'Active',
          'totalScreenTimeMinutes': 150,
          'nightScreenTimeMinutes': 20,
          'isOnline': 1,
          'isLocked': false,
        },
        {
          'id': '102',
          'name': 'Bhavin Shah',
          'room': '205',
          'phone': '',
          'aadhar': '',
          'groupName': 'Pavitra',
          'status': 'Active',
          'totalScreenTimeMinutes': 45,
          'nightScreenTimeMinutes': 0,
          'isOnline': 0,
          'isLocked': true,
        },
        {
          'id': '103',
          'name': 'Chirag Joshi',
          'room': 'alumni',
          'phone': '9123456780',
          'aadhar': '987654321098',
          'groupName': 'Alumni',
          'status': 'Alumni / Left',
          'totalScreenTimeMinutes': 0,
          'nightScreenTimeMinutes': 0,
          'isOnline': 0,
          'isLocked': false,
        },
      ]);
      controller.filterStudents('');
    });

    test('starts with 0 active filter count and active resident students with rooms', () {
      expect(controller.activeFilterCount, equals(0));
      expect(controller.filteredStudents.length, equals(2));
    });

    test('group filter updates activeFilterCount and filters students', () {
      controller.selectGroup('Param');
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first['name'], equals('Aarav Patel'));

      controller.selectGroup('Param'); // toggles off back to All
      expect(controller.activeFilterCount, equals(0));
      expect(controller.filteredStudents.length, equals(2));
    });

    test('floor filter filters students based on room number digits', () {
      controller.selectFloor('Floor 1');
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first['name'], equals('Aarav Patel'));

      controller.selectFloor('Floor 2');
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first['name'], equals('Bhavin Shah'));
    });

    test('status filter separates active residents and alumni', () {
      controller.selectStatus('Active Residents');
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(2));

      controller.selectStatus('Alumni / Left');
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first['name'], equals('Chirag Joshi'));
    });

    test('toggles for heavy usage and locked phone work accurately', () {
      controller.toggleOnlyHeavyUsage(true);
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first['name'], equals('Aarav Patel'));

      controller.toggleOnlyHeavyUsage(false);
      controller.toggleOnlyLocked(true);
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first['name'], equals('Bhavin Shah'));
    });

    test('resetAllFilters resets all states back to default', () {
      controller.selectGroup('Param');
      controller.selectFloor('Floor 1');
      controller.toggleOnlyWithUsage(true);
      controller.selectSort('Name (Z-A)');
      expect(controller.activeFilterCount, equals(4));

      controller.resetAllFilters();
      expect(controller.activeFilterCount, equals(0));
      expect(controller.selectedGroup.value, equals('All'));
      expect(controller.selectedFloor.value, equals('All'));
      expect(controller.onlyWithUsage.value, isFalse);
      expect(controller.filteredStudents.length, equals(2));
    });
  });

  group('Birthday Wishes Filter Button & Logic', () {
    late AdminBirthdayController controller;

    setUp(() {
      controller = AdminBirthdayController();
      controller.allStudents.assignAll([
        const BirthdayStudentModel(
          studentId: 1,
          name: 'Divyesh Patel',
          studentCode: '0101',
          phone: '9876543210',
          whatsappNumber: '9876543210',
          parentPhone: '9876543211',
          room: '105',
          dob: '2004-05-12',
          groupName: 'Param',
          isActive: true,
        ),
        const BirthdayStudentModel(
          studentId: 2,
          name: 'Eshaan Joshi',
          studentCode: '0202',
          phone: '',
          whatsappNumber: '',
          parentPhone: '',
          room: '302',
          dob: '',
          groupName: 'Pulkit',
          isActive: true,
        ),
        const BirthdayStudentModel(
          studentId: 3,
          name: 'Falguni Shah',
          studentCode: '0303',
          phone: '9123456780',
          whatsappNumber: '9123456780',
          parentPhone: '',
          room: 'alumni',
          dob: '2002-11-20',
          groupName: 'Alumni',
          isActive: false,
        ),
      ]);
    });

    test('starts with 0 active filter count and returns all students', () {
      expect(controller.activeFilterCount, equals(0));
      expect(controller.filteredStudents.length, equals(3));
    });

    test('group filter isolates wing celebrants', () {
      controller.selectGroup('Param');
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first.name, equals('Divyesh Patel'));

      controller.selectGroup('Param');
      expect(controller.activeFilterCount, equals(0));
      expect(controller.filteredStudents.length, equals(3));
    });

    test('floor filter matches student room floor', () {
      controller.selectFloor('Floor 1');
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first.name, equals('Divyesh Patel'));

      controller.selectFloor('Floor 3');
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first.name, equals('Eshaan Joshi'));
    });

    test('toggles for with DOB and WhatsApp number work properly', () {
      controller.toggleOnlyWithDob(true);
      expect(controller.activeFilterCount, equals(1));
      expect(controller.filteredStudents.length, equals(2));

      controller.toggleOnlyWithoutDob(true); // Should auto-disable onlyWithDob
      expect(controller.onlyWithDob.value, isFalse);
      expect(controller.filteredStudents.length, equals(1));
      expect(controller.filteredStudents.first.name, equals('Eshaan Joshi'));

      controller.toggleOnlyWithoutDob(false);
      controller.toggleOnlyWithWhatsApp(true);
      expect(controller.filteredStudents.length, equals(2));
    });

    test('resetAllFilters resets all birthday filters back to default', () {
      controller.selectGroup('Param');
      controller.selectFloor('Floor 1');
      controller.toggleOnlyWithParents(true);
      controller.selectSort('Name (Z-A)');
      expect(controller.activeFilterCount, equals(4));

      controller.resetAllFilters();
      expect(controller.activeFilterCount, equals(0));
      expect(controller.selectedGroup.value, equals('All'));
      expect(controller.selectedFloor.value, equals('All'));
      expect(controller.onlyWithParents.value, isFalse);
      expect(controller.filteredStudents.length, equals(3));
    });
  });

  group('Filter Button UI & BottomSheet Test', () {
    testWidgets('Screen Time filter button opens filter bottom sheet', (tester) async {
      final controller = Get.put(ScreenTimeDirectoryController());
      controller.allStudents.assignAll([
        {
          'id': '101',
          'name': 'Aarav Patel',
          'room': '102',
          'phone': '9876543210',
          'totalScreenTimeMinutes': 150,
          'isOnline': 1,
        },
      ]);
      controller.filterStudents('');

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                StudentDirectoryView(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final filterButton = find.byKey(const ValueKey('screentime_directory_filter_button'));
      expect(filterButton, findsOneWidget);

      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      expect(find.text('Filter & Sort Screen Time'), findsOneWidget);
      expect(find.text('DEVICE & SECURITY STATUS'), findsOneWidget);
      expect(find.text('HOSTEL WING / GROUP'), findsOneWidget);
      expect(find.text('HOSTEL FLOOR'), findsOneWidget);
      expect(find.text('RESIDENCE STATUS'), findsOneWidget);
      expect(find.text('USAGE & POLICY ATTRIBUTES'), findsOneWidget);
      expect(find.text('SORT STUDENTS BY'), findsOneWidget);

      Get.delete<ScreenTimeDirectoryController>(force: true);
    });

    testWidgets('Birthday Wishes directory filter button opens filter bottom sheet', (tester) async {
      final controller = Get.put(AdminBirthdayController());
      controller.selectedTab.value = 3; // Directory tab
      controller.dashboard.value = const BirthdayDashboardData(
        config: BirthdayConfigModel(
          isEnabled: true,
          sendTime: '09:00',
          targetAudience: 'all',
          preferWhatsAppNumber: true,
        ),
        todaysBirthdays: [],
        tomorrowsBirthdays: [],
        recentLogs: [],
        isWhatsAppConnected: true,
        senderPhone: '9876543210',
      );
      controller.isLoading.value = false;
      controller.error.value = '';
      controller.allStudents.assignAll([
        const BirthdayStudentModel(
          studentId: 1,
          name: 'Divyesh Patel',
          studentCode: '0101',
          room: '105',
          dob: '2004-05-12',
          isActive: true,
        ),
      ]);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: AdminBirthdayScreen(),
        ),
      );
      await tester.pump();

      final filterButton = find.byKey(const ValueKey('birthday_directory_filter_button'));
      expect(filterButton, findsOneWidget);

      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      expect(find.text('Filter & Sort Celebrants'), findsOneWidget);
      expect(find.text('HOSTEL WING / GROUP'), findsOneWidget);
      expect(find.text('HOSTEL FLOOR'), findsOneWidget);
      expect(find.text('RESIDENCE STATUS'), findsOneWidget);
      expect(find.text('BIRTHDAY & CONTACT ATTRIBUTES'), findsOneWidget);
      expect(find.text('SORT CELEBRANTS BY'), findsOneWidget);

      Get.delete<AdminBirthdayController>(force: true);
    });
  });
}
