import 'dart:math' as math;

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}

enum GeofenceStatus {
  inside,
  outside,
  unknown,
}

/// Validates whether coordinates fall inside the Hari Saurabh Hostel campus perimeter.
class CampusGeofenceService {
  CampusGeofenceService._();
  static final CampusGeofenceService instance = CampusGeofenceService._();

  /// Campus perimeter polygon extracted directly from the user's GeoJSON
  static const List<LatLng> campusPolygon = [
    LatLng(22.558964147296141, 72.91912238597169),
    LatLng(22.558605678567648, 72.917801267508437),
    LatLng(22.558189217570671, 72.917872586892443),
    LatLng(22.558041473335201, 72.917392613903246),
    LatLng(22.55609092462787, 72.918061373839208),
    LatLng(22.555996869562829, 72.91762963788878),
    LatLng(22.555534142766259, 72.917729845593044),
    LatLng(22.55562669134369, 72.918210848692425),
    LatLng(22.553963188882381, 72.918512935146424),
    LatLng(22.554003697052291, 72.918952455256232),
    LatLng(22.55618098579334, 72.919393558763247),
    LatLng(22.557134125502561, 72.919293597367883),
    LatLng(22.558964147296141, 72.91912238597169),
  ];

  /// Standard Ray-Casting algorithm for Point-in-Polygon (PIP) testing.
  /// Returns `true` if (latitude, longitude) is inside the hostel polygon.
  bool isInsideCampus(double lat, double lng) {
    if (campusPolygon.isEmpty) return false;

    bool inside = false;
    int j = campusPolygon.length - 1;

    for (int i = 0; i < campusPolygon.length; i++) {
      final xi = campusPolygon[i].longitude;
      final yi = campusPolygon[i].latitude;
      final xj = campusPolygon[j].longitude;
      final yj = campusPolygon[j].latitude;

      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / ((yj - yi) != 0 ? (yj - yi) : 0.0000001) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  /// Calculates shortest straight-line distance in meters to the perimeter
  double distanceToPerimeterMeters(double lat, double lng) {
    double minDistance = double.infinity;
    for (final point in campusPolygon) {
      final d = _haversineDistance(lat, lng, point.latitude, point.longitude);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Approximate center of campus for maps view
  LatLng get campusCenter {
    double sumLat = 0;
    double sumLng = 0;
    for (final p in campusPolygon) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / campusPolygon.length, sumLng / campusPolygon.length);
  }
}
