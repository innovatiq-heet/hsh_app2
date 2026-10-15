import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/geofence/geofence_policy_model.dart';
import 'package:hsh_app2/core/models/geofence/student_location.dart';
import 'package:hsh_app2/core/services/geofence_service.dart';
import 'package:hsh_app2/features/geofence/controllers/student_locations_controller.dart';

/// Payload shapes as `hsh_api` sends them (`geofence.service.ts`).
void main() {
  group('GeofencePolicyModel', () {
    test('defaults to a 2-minute location interval', () {
      expect(const GeofencePolicyModel().checkIntervalMinutes, 2);
      expect(GeofencePolicyModel.fromJson({'data': {}}).checkIntervalMinutes, 2);
    });

    test('never sends the removed phone-lock flags', () {
      final json = const GeofencePolicyModel(checkIntervalMinutes: 5).toJson();
      expect(json.containsKey('enforcePhoneLock'), isFalse);
      expect(json.containsKey('lockOnBreach'), isFalse);
      expect(json['checkIntervalMinutes'], 5);
    });

    test('parses GET /geofence/policy including a gate pass', () {
      final policy = GeofencePolicyModel.fromJson({
        'status': 'success',
        'data': {
          'startTime': '22:30',
          'endTime': '06:00',
          'isActive': true,
          'checkIntervalMinutes': 1,
          'repeatDays': ['Daily'],
          'lockOnBreach': false,
          'exemptUntil': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
        },
      });
      expect(policy.startTime, const TimeOfDay(hour: 22, minute: 30));
      expect(policy.checkIntervalMinutes, 1);
      expect(policy.isExemptNow, isTrue);
    });

    test('overnight curfew belongs to the day it started', () {
      const policy = GeofencePolicyModel(
        startTime: TimeOfDay(hour: 22, minute: 0),
        endTime: TimeOfDay(hour: 6, minute: 0),
        repeatDays: ['Mon'],
      );
      expect(policy.isWithinCurfew(DateTime(2026, 10, 5, 23, 0)), isTrue, reason: 'Monday 23:00');
      expect(policy.isWithinCurfew(DateTime(2026, 10, 6, 1, 30)), isTrue, reason: "Tuesday 01:30 is Monday's curfew");
      expect(policy.isWithinCurfew(DateTime(2026, 10, 6, 23, 0)), isFalse, reason: 'Tuesday evening is not configured');
      expect(policy.isWithinCurfew(DateTime(2026, 10, 5, 12, 0)), isFalse, reason: 'daytime');
    });

    test('an inactive curfew is never in effect', () {
      const policy = GeofencePolicyModel(isActive: false);
      expect(policy.isWithinCurfew(DateTime(2026, 10, 5, 23, 0)), isFalse);
    });
  });

  group('StudentLocation', () {
    final fixTime = DateTime.utc(2026, 10, 6, 10, 15).millisecondsSinceEpoch;

    StudentLocation parse(Map<String, dynamic>? location) => StudentLocation.fromJson({
          'studentId': '120',
          'studentCode': '0768',
          'name': 'Asha Patel',
          'room': '204',
          'phone': '9999999999',
          'parentPhone': '',
          'location': location,
        });

    test('a student without a report has no location', () {
      final s = parse(null);
      expect(s.location, isNull);
      expect(s.status, LocationStatus.noData);
    });

    test('parses GET /geofence/locations and classifies inside / outside', () {
      final outside = parse({
        'latitude': 22.57,
        'longitude': 72.93,
        'accuracyMeters': 8,
        'mocked': false,
        'insideCampus': false,
        'distanceMeters': 1500,
        'fixTime': fixTime,
        'receivedAt': fixTime + 2000,
      });
      expect(outside.status, LocationStatus.outside);
      expect(outside.location!.distanceMeters, 1500);
      expect(outside.location!.fixTime.toUtc(), DateTime.utc(2026, 10, 6, 10, 15));

      final inside = parse({'latitude': 22.557, 'longitude': 72.918, 'insideCampus': true, 'fixTime': fixTime});
      expect(inside.status, LocationStatus.inside);
    });

    test('a fix without an inside/outside verdict is "location known"', () {
      expect(parse({'latitude': 22.5, 'longitude': 72.9, 'fixTime': fixTime}).status, LocationStatus.unknownArea);
    });

    test('flags fake GPS and builds a Google Maps link', () {
      final s = parse({'latitude': 22.5571, 'longitude': 72.9185, 'mocked': true, 'insideCampus': true, 'fixTime': fixTime});
      expect(s.location!.mocked, isTrue);
      expect(s.location!.mapsUri.toString(), 'https://www.google.com/maps/search/?api=1&query=22.5571,72.9185');
    });
  });

  group('Campus Geofence & Map View support', () {
    test('CampusGeofenceService contains non-empty polygon for Hari Saurabh Hostel', () {
      expect(CampusGeofenceService.campusPolygon.isNotEmpty, isTrue);
      expect(CampusGeofenceService.campusPolygon.length, greaterThanOrEqualTo(4));
      // Campus center coordinates should fall inside the campus polygon
      final inside = CampusGeofenceService.instance.isInsideCampus(22.5565, 72.9185);
      expect(inside, isTrue);
    });

    test('StudentLocationsController toggleViewMode toggles isMapView and resets selection', () {
      final controller = StudentLocationsController();
      expect(controller.isMapView.value, isFalse);

      controller.toggleViewMode();
      expect(controller.isMapView.value, isTrue);

      controller.selectedStudent.value = StudentLocation.fromJson({
        'studentId': '101',
        'studentCode': '001',
        'name': 'Test Student',
        'room': '101',
      });
      expect(controller.selectedStudent.value, isNotNull);

      // Toggling back to list view clears selection
      controller.toggleViewMode();
      expect(controller.isMapView.value, isFalse);
      expect(controller.selectedStudent.value, isNull);
    });
  });
}
