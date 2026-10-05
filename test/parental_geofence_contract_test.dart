import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/geofence/geofence_breach_event.dart';
import 'package:hsh_app2/features/screentime/models/screen_time_policy.dart';

/// Payload shapes as the backend (`screentime.routes.ts`, `geofence.service.ts`) sends them.
void main() {
  group('ScreenTimePolicy.tryParse', () {
    test('GET /screen-time/policies/me: null bedtime means no curfew', () {
      final policy = ScreenTimePolicy.tryParse({
        'success': true,
        'data': {
          'policy': {'policy_version': 3, 'daily_limit_minutes': 120, 'bedtime_start': null, 'bedtime_end': null, 'is_locked': 0},
          'apps': [],
          'blockedPackages': ['com.instagram.android'],
        },
      }, current: const ScreenTimePolicy(bedtimeStart: '22:00', bedtimeEnd: '06:00'));

      expect(policy, isNotNull);
      expect(policy!.hasBedtime, isFalse);
      expect(policy.bedtimeStart, '');
      expect(policy.blockedPackages, {'com.instagram.android'});
      expect(policy.dailyLimitMinutes, 120);
      expect(policy.isLocked, isFalse);
      expect(policy.version, '3');
    });

    test('MySQL TIME values are normalised to HH:mm', () {
      final policy = ScreenTimePolicy.tryParse({
        'data': {
          'policy': {'bedtime_start': '23:00:00', 'bedtime_end': '05:30:00', 'is_locked': 1},
        },
      });
      expect(policy!.bedtimeStart, '23:00');
      expect(policy.bedtimeEnd, '05:30');
      expect(policy.isLocked, isTrue);
    });

    test('a payload without bedtime keys keeps the current curfew', () {
      final policy = ScreenTimePolicy.tryParse(
        {'data': {'isOnline': true, 'policy': null, 'blockedPackages': []}},
        current: const ScreenTimePolicy(bedtimeStart: '23:00', bedtimeEnd: '05:00'),
      );
      expect(policy!.bedtimeStart, '23:00');
      expect(policy.blockedPackages, isEmpty);
    });

    test('default policy has no curfew', () {
      expect(const ScreenTimePolicy().hasBedtime, isFalse);
    });
  });

  group('GeofenceBreachEvent.fromJson', () {
    test('parses GET /geofence/breaches rows (epoch-millis times)', () {
      final at = DateTime.utc(2026, 10, 5, 17, 30).millisecondsSinceEpoch;
      final e = GeofenceBreachEvent.fromJson({
        'id': 'breach_x',
        'studentId': '120',
        'studentName': 'A Student',
        'room': '204',
        'phone': '9999999999',
        'parentPhone': '8888888888',
        'latitude': 22.55,
        'longitude': 72.91,
        'distanceMeters': 140.5,
        'accuracyMeters': 12,
        'mocked': false,
        'type': 'exit',
        'actionTaken': 'calledStudent',
        'isResolved': false,
        'timestamp': at,
        'lastSeenAt': at,
        'returnedAt': null,
      });
      expect(e.timestamp.toUtc(), DateTime.utc(2026, 10, 5, 17, 30));
      expect(e.eventType, BreachEventType.exit);
      expect(e.actionTaken, BreachActionStatus.calledStudent);
      expect(e.parentPhone, '8888888888');
      expect(e.formattedDistance, '141m outside');
    });

    test('location_off and returned breaches render their own status', () {
      final off = GeofenceBreachEvent.fromJson({'id': 'a', 'type': 'location_off', 'timestamp': 1}).formattedDistance;
      expect(off, 'Location turned off');

      final back = GeofenceBreachEvent.fromJson({
        'id': 'b',
        'type': 'exit',
        'distanceMeters': 300,
        'timestamp': 1759685400000,
        'returnedAt': 1759689000000,
      });
      expect(back.formattedDistance, 'Back on campus');
      expect(back.durationOutside, const Duration(hours: 1));
    });
  });
}
