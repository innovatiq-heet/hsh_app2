/// A student and the last location their phone reported (`GET /geofence/locations`).
class StudentLocation {
  final String studentId;
  final String studentCode;
  final String name;
  final String room;
  final String phone;
  final String parentPhone;

  /// Null until the phone has reported a fix (location off, not set up yet…).
  final LocationFix? location;

  const StudentLocation({
    required this.studentId,
    required this.studentCode,
    required this.name,
    required this.room,
    required this.phone,
    required this.parentPhone,
    this.location,
  });

  factory StudentLocation.fromJson(Map<dynamic, dynamic> json) {
    final loc = json['location'];
    return StudentLocation(
      studentId: (json['studentId'] ?? json['id'] ?? '').toString(),
      studentCode: (json['studentCode'] ?? json['student_code'] ?? '').toString(),
      name: (json['name'] ?? 'Student').toString(),
      room: (json['room'] ?? 'N/A').toString(),
      phone: (json['phone'] ?? '').toString(),
      parentPhone: (json['parentPhone'] ?? '').toString(),
      location: loc is Map ? LocationFix.fromJson(loc) : null,
    );
  }
}

enum LocationStatus { outside, inside, unknownArea, noData }

class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool mocked;

  /// Null when the phone couldn't tell (older build); otherwise from the campus fence.
  final bool? insideCampus;
  final double? distanceMeters;

  /// When the phone took the fix.
  final DateTime fixTime;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.mocked,
    required this.insideCampus,
    required this.distanceMeters,
    required this.fixTime,
  });

  factory LocationFix.fromJson(Map<dynamic, dynamic> json) => LocationFix(
        latitude: _toDouble(json['latitude']) ?? 0,
        longitude: _toDouble(json['longitude']) ?? 0,
        accuracyMeters: _toDouble(json['accuracyMeters']) ?? 0,
        mocked: json['mocked'] == true,
        insideCampus: json['insideCampus'] is bool ? json['insideCampus'] as bool : null,
        distanceMeters: _toDouble(json['distanceMeters']),
        fixTime: DateTime.fromMillisecondsSinceEpoch((_toDouble(json['fixTime']) ?? 0).toInt()),
      );

  /// Google Maps link for this point (opens the Maps app when installed).
  Uri get mapsUri => Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

extension StudentLocationX on StudentLocation {
  LocationStatus get status {
    final loc = location;
    if (loc == null) return LocationStatus.noData;
    if (loc.insideCampus == null) return LocationStatus.unknownArea;
    return loc.insideCampus! ? LocationStatus.inside : LocationStatus.outside;
  }
}
