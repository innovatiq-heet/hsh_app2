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

/// Campus perimeter maths for the admin UI (map preview, distance labels).
///
/// Enforcement happens natively in `GeofenceEvaluator.kt`, which carries the
/// same polygon; keep the two in sync if the outline changes.
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
  ];

  /// Ray casting point-in-polygon. Horizontal edges never satisfy the first
  /// test, so the division below is always safe.
  bool isInsideCampus(double lat, double lng) {
    bool inside = false;
    int j = campusPolygon.length - 1;
    for (int i = 0; i < campusPolygon.length; i++) {
      final xi = campusPolygon[i].longitude, yi = campusPolygon[i].latitude;
      final xj = campusPolygon[j].longitude, yj = campusPolygon[j].latitude;
      if (((yi > lat) != (yj > lat)) && (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// Shortest distance in metres from the point to the fence **edge**.
  ///
  /// Uses a flat projection centred on the point; error is negligible over a
  /// few hundred metres. (Measuring to the nearest *corner* overstated the
  /// distance by up to the half-length of an edge.)
  double distanceToPerimeterMeters(double lat, double lng) {
    const mPerDegLat = 110540.0;
    final mPerDegLng = 111320.0 * math.cos(lat * math.pi / 180);

    double best = double.infinity;
    int j = campusPolygon.length - 1;
    for (int i = 0; i < campusPolygon.length; i++) {
      final ax = (campusPolygon[j].longitude - lng) * mPerDegLng;
      final ay = (campusPolygon[j].latitude - lat) * mPerDegLat;
      final bx = (campusPolygon[i].longitude - lng) * mPerDegLng;
      final by = (campusPolygon[i].latitude - lat) * mPerDegLat;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      best = math.min(best, math.sqrt(cx * cx + cy * cy));
      j = i;
    }
    return best;
  }

  /// Approximate center of campus for maps view
  LatLng get campusCenter {
    double sumLat = 0, sumLng = 0;
    for (final p in campusPolygon) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / campusPolygon.length, sumLng / campusPolygon.length);
  }
}
