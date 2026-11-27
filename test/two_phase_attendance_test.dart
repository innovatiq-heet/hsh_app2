import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/enums/attendance_type.dart';
import 'package:hsh_app2/core/network/api_exception.dart';
import 'package:hsh_app2/core/network/repository/attendance/attendance_repository.dart';
import 'package:hsh_app2/core/network/repository/floors/floor_strings_repository.dart';
import 'package:hsh_app2/core/network/request/attendance/mark_attendance_request.dart';
import 'package:hsh_app2/core/network/responses/attendance/attendance_models.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/attendance/controllers/attendance_controller.dart';
import 'package:hsh_app2/features/attendance/views/attendance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weekdaysFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final todayFull = weekdaysFull[DateTime.now().weekday - 1];

  group('AttendanceScheduleItem two-phase helpers', () {
    test('parses phase2 fields from day_schedules slot when top-level omitted', () {
      final item = AttendanceScheduleItem.fromJson({
        'session_key': 'aarti',
        'session_name': 'Evening Aarti',
        'icon_name': 'flame',
        'start_time': '18:00:00',
        'end_time': '18:30:00',
        'day_schedules': [
          {
            'days': [todayFull],
            'startTime': '18:45',
            'endTime': '19:20',
            'lateTime': '19:10',
            'hasMultipleAttendance': true,
            'phase2StartTime': '19:25',
            'phase2EndTime': '19:35',
            'phase2LateTime': '19:30',
          },
        ],
      });

      expect(item.isScheduledToday, isTrue);
      expect(item.startTime, '18:45');
      expect(item.endTime, '19:20');
      expect(item.lateTime, '19:10');
      expect(item.hasMultipleAttendance, isTrue);
      expect(item.phase2StartTime, '19:25');
      expect(item.phase2EndTime, '19:35');
      expect(item.phase2LateTime, '19:30');
    });

    test('identifies Phase 2 open, waiting between windows, ineligible, and complete', () {
      final p2Open = AttendanceScheduleItem.fromJson({
        'session_key': 'aarti',
        'session_name': 'Aarti',
        'start_time': '18:45',
        'end_time': '19:20',
        'has_multiple_attendance': true,
        'phase2_start_time': '19:25',
        'phase2_end_time': '19:35',
        'active_phase': 2,
        'can_mark': true,
        'overall_status': 'live',
        'first_attendance': {
          'is_open_now': false,
          'is_marked': true,
          'status': 'marked',
        },
        'second_attendance': {
          'is_open_now': true,
          'is_marked': false,
          'is_eligible': true,
          'status': 'live',
        },
      });

      expect(p2Open.isPhase1Marked, isTrue);
      expect(p2Open.isPhase2Marked, isFalse);
      expect(p2Open.currentOpenPhase(), 2);
      expect(p2Open.canMarkPhaseNow(), isTrue);
      expect(p2Open.isCompletedToday(), isFalse);
      expect(p2Open.isPhase2Ineligible(), isFalse);

      final ineligible = AttendanceScheduleItem.fromJson({
        'session_key': 'aarti',
        'session_name': 'Aarti',
        'start_time': '18:45',
        'end_time': '19:20',
        'has_multiple_attendance': true,
        'phase2_start_time': '19:25',
        'phase2_end_time': '19:35',
        'active_phase': 2,
        'can_mark': false,
        'overall_status': 'absent',
        'first_attendance': {
          'is_open_now': false,
          'is_marked': false,
          'status': 'absent',
        },
        'second_attendance': {
          'is_open_now': true,
          'is_marked': false,
          'is_eligible': false,
          'status': 'not_eligible',
        },
      });

      expect(ineligible.canMarkPhaseNow(), isFalse);
      expect(ineligible.isPhase2Ineligible(), isTrue);
      expect(ineligible.isCompletedToday(), isFalse);

      final between = AttendanceScheduleItem.fromJson({
        'session_key': 'aarti',
        'session_name': 'Aarti',
        'start_time': '18:45',
        'end_time': '19:20',
        'has_multiple_attendance': true,
        'phase2_start_time': '19:25',
        'phase2_end_time': '19:35',
        'active_phase': null,
        'can_mark': false,
        'overall_status': 'upcoming',
        'first_attendance': {
          'is_open_now': false,
          'is_marked': true,
          'status': 'marked',
        },
        'second_attendance': {
          'is_open_now': false,
          'is_marked': false,
          'is_eligible': true,
          'status': 'upcoming',
        },
      });

      expect(
        between.isWaitingForPhase2(DateTime(2026, 11, 27, 19, 22)),
        isTrue,
      );
      expect(
        between.isWaitingForPhase2(DateTime(2026, 11, 27, 19, 40)),
        isFalse,
      );
    });
  });

  group('AttendanceRepository and AttendanceController two-phase flow', () {
    late FakeApi api;

    setUp(() async {
      Get.reset();
      SharedPreferences.setMockInitialValues({
        'hsh_token': 'test-token',
        'hsh_role': 'student',
        'hsh_student_name': 'Test Student',
        'hsh_room': '101',
        'hsh_student_code': '0001',
      });
      api = FakeApi()..install();
      Get.put(SessionStore());
      Get.put(AttendanceRepository());
      Get.put(FloorStringsRepository());
    });

    tearDown(() {
      Get.reset();
    });

    test('mark() parses top-level phase/message and preserves ApiException code', () async {
      api.on('POST /attendance/mark', {
        'success': true,
        'phase': 2,
        'is_late': true,
        'message': 'Second attendance marked successfully',
      }, status: 201);

      final repo = Get.find<AttendanceRepository>();
      final record = await repo.mark(
        const MarkAttendanceRequest(
          type: AttendanceType.aarti,
          sessionKey: 'aarti',
          targetPhase: 2,
          viaCode: false,
          rssi: -52,
        ),
      );

      final sent = api.last('POST /attendance/mark').data as Map;
      expect(sent['target_phase'], 2);
      expect(sent['session_key'], 'aarti');
      expect(record.phase, 2);
      expect(record.isLate, isTrue);
      expect(record.message, 'Second attendance marked successfully');

      api.on('POST /attendance/mark', {
        'success': false,
        'code': 'NOT_ELIGIBLE_MISSED_FIRST',
        'message': 'You are not eligible to mark second attendance because you did not complete the first attendance.',
      }, status: 403);

      await expectLater(
        repo.mark(
          const MarkAttendanceRequest(
            type: AttendanceType.aarti,
            sessionKey: 'aarti',
            targetPhase: 2,
            viaCode: false,
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'NOT_ELIGIBLE_MISSED_FIRST',
          ),
        ),
      );
    });

    test('load() preserves Phase 2 availability even after Phase 1 history exists', () async {
      api.on('GET /attendance/my-status', {
        'success': true,
        'data': {
          'already_marked': false,
          'attendance_active': true,
          'active_session_type': 'aarti',
          'session_name': 'Aarti',
          'start_time': '19:25',
          'end_time': '19:35',
          'all_schedules': [
            {
              'session_key': 'aarti',
              'session_name': 'Aarti',
              'icon_name': 'flame',
              'start_time': '18:45',
              'end_time': '19:20',
              'has_multiple_attendance': true,
              'phase2_start_time': '19:25',
              'phase2_end_time': '19:35',
              'active_phase': 2,
              'can_mark': true,
              'overall_status': 'live',
              'is_active_today': true,
              'first_attendance': {
                'start_time': '18:45',
                'end_time': '19:20',
                'is_open_now': false,
                'is_marked': true,
                'marked_at': DateTime.now().toIso8601String(),
                'is_late': false,
                'status': 'marked',
              },
              'second_attendance': {
                'start_time': '19:25',
                'end_time': '19:35',
                'is_open_now': true,
                'is_marked': false,
                'is_eligible': true,
                'status': 'live',
              },
            },
          ],
        },
      });

      api.on('GET /attendance/history', {
        'success': true,
        'data': [
          {
            'id': 91,
            'session_type': 'aarti',
            'session_key': 'aarti',
            'phase': 1,
            'marked_at': DateTime.now().toIso8601String(),
            'viaCode': false,
          },
        ],
      });

      final controller = Get.put(AttendanceController());
      await controller.load(showLoading: false);

      final aarti = controller.schedulesList.firstWhere(
        (s) => s.sessionKey == 'aarti',
      );
      expect(aarti.hasMultipleAttendance, isTrue);
      expect(aarti.activePhase, 2);
      expect(aarti.canMark, isTrue);
      expect(aarti.isPhase1Marked, isTrue);
      expect(aarti.isPhase2Marked, isFalse);
      expect(aarti.isCompletedToday(), isFalse);
      expect(aarti.canMarkPhaseNow(), isTrue);
      expect(controller.todaySessionPhases['aarti'], contains(1));
      expect(controller.todaySessionStatus['aarti'], isNull);
      expect(controller.todayStatus[AttendanceType.aarti], isNull);

      // Phase 1 onAttendanceMarked should NOT mark session complete
      controller.onAttendanceMarked(
        AttendanceRecord(
          id: 92,
          date: DateTime.now(),
          time: DateTime.now(),
          type: AttendanceType.aarti,
          viaCode: false,
          phase: 1,
          sessionKey: 'aarti',
        ),
      );
      expect(controller.todaySessionStatus['aarti'], isNull);

      // Phase 2 onAttendanceMarked marks the two-phase session complete
      controller.onAttendanceMarked(
        AttendanceRecord(
          id: 93,
          date: DateTime.now(),
          time: DateTime.now(),
          type: AttendanceType.aarti,
          viaCode: false,
          phase: 2,
          sessionKey: 'aarti',
        ),
      );
      expect(controller.todaySessionStatus['aarti'], isNotNull);
      expect(controller.todayStatus[AttendanceType.aarti], isNotNull);
      expect(controller.todaySessionPhases['aarti'], containsAll([1, 2]));

      // friendlyError maps phase codes accurately
      expect(
        controller.friendlyError(
          const ApiException('missed first', code: 'NOT_ELIGIBLE_MISSED_FIRST'),
        ),
        contains('missed 1st attendance'),
      );
      expect(
        controller.friendlyError(
          const ApiException(
            'First attendance already marked for this session',
            statusCode: 400,
          ),
        ),
        'First attendance already marked for this session',
      );
    });

    testWidgets('AttendanceScreen renders two-phase rows and Mark 2nd / Ineligible pills', (tester) async {
      api.on('GET /attendance/my-status', {
        'success': true,
        'data': {
          'already_marked': false,
          'attendance_active': true,
          'active_session_type': 'aarti',
          'all_schedules': [
            {
              'session_key': 'aarti',
              'session_name': 'Evening Aarti',
              'icon_name': 'flame',
              'start_time': '18:45',
              'end_time': '19:20',
              'has_multiple_attendance': true,
              'phase2_start_time': '19:25',
              'phase2_end_time': '19:35',
              'active_phase': 2,
              'can_mark': true,
              'overall_status': 'live',
              'is_active_today': true,
              'first_attendance': {
                'start_time': '18:45',
                'end_time': '19:20',
                'is_open_now': false,
                'is_marked': true,
                'status': 'marked',
              },
              'second_attendance': {
                'start_time': '19:25',
                'end_time': '19:35',
                'is_open_now': true,
                'is_marked': false,
                'is_eligible': true,
                'status': 'live',
              },
            },
            {
              'session_key': 'night',
              'session_name': 'Night Check',
              'icon_name': 'moon',
              'start_time': '22:00',
              'end_time': '22:15',
              'has_multiple_attendance': true,
              'phase2_start_time': '22:30',
              'phase2_end_time': '22:45',
              'active_phase': 2,
              'can_mark': false,
              'overall_status': 'absent',
              'is_active_today': true,
              'first_attendance': {
                'start_time': '22:00',
                'end_time': '22:15',
                'is_open_now': false,
                'is_marked': false,
                'status': 'absent',
              },
              'second_attendance': {
                'start_time': '22:30',
                'end_time': '22:45',
                'is_open_now': true,
                'is_marked': false,
                'is_eligible': false,
                'status': 'not_eligible',
              },
            },
          ],
        },
      });
      api.on('GET /attendance/history', {'success': true, 'data': []});

      await tester.runAsync(() async {
        final controller = Get.put(AttendanceController());
        await controller.load(showLoading: false);
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: AttendanceScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Evening Aarti'), findsOneWidget);
      expect(find.text('1st: 18:45–19:20'), findsOneWidget);
      expect(find.text('2nd: 19:25–19:35'), findsOneWidget);
      expect(find.text('Mark 2nd'), findsOneWidget);
      expect(find.text('Ineligible'), findsAtLeastNWidgets(1));
    });
  });
}
