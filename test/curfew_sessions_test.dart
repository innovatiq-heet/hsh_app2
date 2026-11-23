import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_utils.dart' hide formatMinutes;
import 'package:hsh_app2/features/screentime/curfew/curfew_schedule.dart';
import 'package:hsh_app2/features/screentime/curfew/models.dart';
import 'package:hsh_app2/features/screentime/curfew/screen_time_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// IST wall-clock → UTC instant.
DateTime ist(int y, int mo, int d, int h, int mi) => DateTime.utc(y, mo, d, h, mi).subtract(kIstOffset);

/// Curfew sessions: the schedule maths (same cases as the backend and the
/// native `CurfewScheduleTest`) and the admin API contract.
void main() {
  group('curfew schedule (2026-11-23 is a Monday)', () {
    const monOnlyNight = CurfewWindow(startTime: '22:00', endTime: '06:00', days: ['mon']);

    test('an overnight window belongs to the day it starts on', () {
      expect(monOnlyNight.isRunning(ist(2026, 11, 23, 21, 59)), isFalse);
      expect(monOnlyNight.isRunning(ist(2026, 11, 23, 22, 0)), isTrue);
      expect(monOnlyNight.isRunning(ist(2026, 11, 24, 5, 59)), isTrue);
      expect(monOnlyNight.isRunning(ist(2026, 11, 24, 6, 0)), isFalse);
      expect(monOnlyNight.isRunning(ist(2026, 11, 24, 23, 0)), isFalse);
      expect(monOnlyNight.isRunning(ist(2026, 11, 23, 3, 0)), isFalse);
    });

    test('next start and current end', () {
      expect(monOnlyNight.nextStart(ist(2026, 11, 24, 10, 0)), ist(2026, 11, 30, 22, 0));
      expect(monOnlyNight.currentEnd(ist(2026, 11, 23, 23, 0)), ist(2026, 11, 24, 6, 0));
      expect(monOnlyNight.currentEnd(ist(2026, 11, 24, 12, 0)), isNull);
    });

    test('policy payload: union of sessions, legacy fallback', () {
      final set = PhoneCurfewSet.fromPolicy({
        'curfew_sessions': [
          {'id': 1, 'name': 'Night', 'start_time': '22:00', 'end_time': '06:00', 'days': kDayKeys, 'source': 'session'},
          {'id': 2, 'name': 'Study', 'start_time': '14:00', 'end_time': '16:00', 'days': ['mon'], 'source': 'session'},
        ],
      });
      expect(set.isInCurfew(ist(2026, 11, 23, 15, 0)), isTrue);
      expect(set.isInCurfew(ist(2026, 11, 24, 15, 0)), isFalse);
      expect(set.isInCurfew(ist(2026, 11, 24, 23, 0)), isTrue);
      expect(set.nextChange(ist(2026, 11, 24, 15, 0)), ist(2026, 11, 24, 22, 0));

      final legacy = PhoneCurfewSet.fromPolicy({'bedtime_start': '23:00:00', 'bedtime_end': '05:00:00'});
      expect(legacy.isInCurfew(ist(2026, 11, 24, 1, 0)), isTrue);
      expect(PhoneCurfewSet.fromPolicy({'curfew_sessions': []}).isEmpty, isTrue);
    });

    test('describeDays and formatMinutes match the server', () {
      expect(describeDays(kDayKeys), 'every day');
      expect(describeDays(['mon', 'tue', 'wed', 'thu', 'fri']), 'Mon–Fri');
      expect(describeDays(['mon', 'wed', 'fri']), 'Mon, Wed, Fri');
      expect(formatMinutes(190), '3 h 10 min');
      expect(formatMinutes(3120), '2 d 4 h');
    });
  });

  group('connection status', () {
    test('the server status wins and has no gap', () {
      expect(connectionStatusOf({'connectionStatus': 'quiet', 'isOnline': false}), 'quiet');
      expect(isStudentDisconnected({'connectionStatus': 'quiet', 'isOnline': false}), isFalse);
      expect(isStudentDisconnected({'connectionStatus': 'offline', 'isOnline': false}), isTrue);
    });

    test('older servers: derived from isOnline', () {
      expect(connectionStatusOf({'isOnline': true}), 'online');
      expect(connectionStatusOf({'isOnline': false}), 'offline');
    });
  });

  group('admin API', () {
    late FakeApi api;

    setUp(() async {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'warden-token',
        'user_session': jsonEncode({'role': 'warden', 'token': 'warden-token', 'name': 'Warden'}),
      });
      Get.put(SessionStore());
      api = FakeApi()..install();
    });

    tearDown(Get.reset);

    test('bulk add sends numeric students.id only', () async {
      api.on('POST /screen-time/sessions/3/students', {
        'success': true,
        'data': {'added_count': 2},
      });
      final added = await ScreenTimeApi().addStudents(
        3,
        const StudentSelection(studentIds: [12, 40], groups: ['Param']),
      );
      expect(added, 2);
      final body = api.last('POST /screen-time/sessions/3/students').data as Map;
      expect(body['student_ids'], [12, 40]);
      expect(body['groups'], ['Param']);
      expect(body.containsKey('student_code'), isFalse);
    });

    test('edit is a partial PATCH', () async {
      api.on('PATCH /screen-time/sessions/7', {
        'success': true,
        'data': {'id': 7, 'name': 'Study', 'start_time': '14:00', 'end_time': '16:00', 'days': ['mon'], 'is_active': false},
      });
      final s = await ScreenTimeApi().setSessionActive(7, false);
      expect(s.isActive, isFalse);
      expect(api.last('PATCH /screen-time/sessions/7').data, {'is_active': false});
    });

    test("a refusal carries the server's message and data", () async {
      api.on(
        'POST /screen-time/sessions/3/students',
        {'success': false, 'message': 'Unknown students', 'data': {'invalid_student_ids': [99]}},
        status: 400,
      );
      await expectLater(
        ScreenTimeApi().addStudents(3, const StudentSelection(studentIds: [99])),
        throwsA(isA<ScreenTimeApiException>()
            .having((e) => e.message, 'message', 'Unknown students')
            .having((e) => e.data?['invalid_student_ids'], 'invalid ids', [99])),
      );
    });
  });
}
