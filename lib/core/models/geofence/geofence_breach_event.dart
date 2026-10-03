enum BreachActionStatus {
  none,
  phoneLocked,
  calledStudent,
  calledParent,
  warningSent,
  gatePassGranted,
  dismissed,
}

/// What the device reported: a confirmed exit, a periodic heartbeat while
/// still outside, a return to campus, or a spoofed-location attempt.
enum BreachEventType { exit, heartbeat, enter, mockLocation, unknown }

/// A curfew breach as the backend records it from device geofence events.
class GeofenceBreachEvent {
  final String id;
  final String studentId;
  final String studentName;
  final String room;
  final String phone;
  final String parentPhone;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double accuracyMeters;
  final bool isMocked;
  final BreachEventType eventType;
  final DateTime timestamp;

  /// When the student came back (null while still outside).
  final DateTime? returnedAt;
  BreachActionStatus actionTaken;
  bool isResolved;

  GeofenceBreachEvent({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.room,
    required this.phone,
    this.parentPhone = '',
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.accuracyMeters = 0,
    this.isMocked = false,
    this.eventType = BreachEventType.exit,
    required this.timestamp,
    this.returnedAt,
    this.actionTaken = BreachActionStatus.none,
    this.isResolved = false,
  });

  String get formattedDistance {
    if (isMocked) return 'Fake GPS detected';
    if (distanceMeters < 1000) return '${distanceMeters.round()}m outside';
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km outside';
  }

  /// How long they've been (or were) outside.
  Duration get durationOutside => (returnedAt ?? DateTime.now()).difference(timestamp);

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'room': room,
        'phone': phone,
        'parentPhone': parentPhone,
        'latitude': latitude,
        'longitude': longitude,
        'distanceMeters': distanceMeters,
        'accuracyMeters': accuracyMeters,
        'mocked': isMocked,
        'type': eventType.name,
        'timestamp': timestamp.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
        'actionTaken': actionTaken.name,
        'isResolved': isResolved,
      };

  factory GeofenceBreachEvent.fromJson(Map<dynamic, dynamic> json) {
    final student = json['student'] is Map ? json['student'] as Map : const {};
    return GeofenceBreachEvent(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      studentId: (json['studentId'] ?? json['student_id'] ?? json['aadhar'] ?? student['aadhar'] ?? '').toString(),
      studentName: (json['studentName'] ?? json['student_name'] ?? student['name'] ?? 'Unknown Student').toString(),
      room: (json['room'] ?? json['room_number'] ?? student['room'] ?? 'N/A').toString(),
      phone: (json['phone'] ?? student['phone'] ?? '').toString(),
      parentPhone: (json['parentPhone'] ?? json['parent_phone'] ?? student['parentPhone'] ?? '').toString(),
      latitude: _toDouble(json['latitude'] ?? json['lat']),
      longitude: _toDouble(json['longitude'] ?? json['lng']),
      distanceMeters: _toDouble(json['distanceMeters'] ?? json['distance_meters']),
      accuracyMeters: _toDouble(json['accuracyMeters'] ?? json['accuracy_meters']),
      isMocked: _toBool(json['mocked'] ?? json['isMocked'] ?? json['is_mocked']) ?? false,
      eventType: _parseType(json['type'] ?? json['eventType'] ?? json['event_type']),
      timestamp: _toDate(json['timestamp'] ?? json['at'] ?? json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      returnedAt: _toDate(json['returnedAt'] ?? json['returned_at'] ?? json['resolvedAt']),
      actionTaken: BreachActionStatus.values.firstWhere(
        (e) => e.name == (json['actionTaken'] ?? json['action_taken'])?.toString(),
        orElse: () => BreachActionStatus.none,
      ),
      isResolved: _toBool(json['isResolved'] ?? json['is_resolved']) ?? false,
    );
  }

  static BreachEventType _parseType(dynamic v) {
    switch (v?.toString()) {
      case 'exit':
        return BreachEventType.exit;
      case 'heartbeat':
        return BreachEventType.heartbeat;
      case 'enter':
        return BreachEventType.enter;
      case 'mock_location':
      case 'mockLocation':
        return BreachEventType.mockLocation;
      default:
        return v == null ? BreachEventType.exit : BreachEventType.unknown;
    }
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static bool? _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v > 1e12 ? v.toInt() : v.toInt() * 1000);
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
