enum BreachActionStatus {
  none,
  phoneLocked,
  calledStudent,
  calledParent,
  warningSent,
  gatePassGranted,
  dismissed,
}

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
  final DateTime timestamp;
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
    required this.timestamp,
    this.actionTaken = BreachActionStatus.none,
    this.isResolved = false,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m away';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km away';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'room': room,
      'phone': phone,
      'parentPhone': parentPhone,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'timestamp': timestamp.toIso8601String(),
      'actionTaken': actionTaken.name,
      'isResolved': isResolved,
    };
  }

  factory GeofenceBreachEvent.fromJson(Map<String, dynamic> json) {
    BreachActionStatus parseStatus(String? name) {
      return BreachActionStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => BreachActionStatus.none,
      );
    }

    return GeofenceBreachEvent(
      id: (json['id'] ?? '').toString(),
      studentId: (json['studentId'] ?? json['student_id'] ?? '').toString(),
      studentName: (json['studentName'] ?? json['student_name'] ?? 'Unknown Student').toString(),
      room: (json['room'] ?? json['room_number'] ?? 'N/A').toString(),
      phone: (json['phone'] ?? '').toString(),
      parentPhone: (json['parentPhone'] ?? json['parent_phone'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] ?? json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      actionTaken: parseStatus(json['actionTaken']?.toString() ?? json['action_taken']?.toString()),
      isResolved: json['isResolved'] ?? json['is_resolved'] ?? false,
    );
  }
}
