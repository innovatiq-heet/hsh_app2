import 'package:latlong2/latlong.dart' as ll;

/// One breadcrumb of a student's phone (`GET /geofence/history/:id`).
class TrailPoint {
  final ll.LatLng point;
  final DateTime? time;
  final double accuracyMeters;
  final bool? insideCampus;
  final bool mocked;

  const TrailPoint({
    required this.point,
    this.time,
    this.accuracyMeters = 0,
    this.insideCampus,
    this.mocked = false,
  });
}

/// A student's recent movement, cleaned up for drawing: oldest to newest,
/// without empty coordinates and without the jitter of a phone sitting still.
class LocationTrail {
  static const empty = LocationTrail._([]);
  static const _distance = ll.Distance();
  static const _timeKeys = [
    'fixTime', 'fix_time', 'recordedAt', 'recorded_at', 'createdAt', 'created_at', 'timestamp', 'time',
  ];

  final List<TrailPoint> points;

  const LocationTrail._(this.points);

  /// [minStepMeters]: a fix closer than this to the previous kept one is dropped.
  factory LocationTrail.parse(List<Map<String, dynamic>> rows, {double minStepMeters = 5}) {
    final parsed = <TrailPoint>[];
    for (final row in rows) {
      final lat = _num(row['latitude'] ?? row['lat']);
      final lng = _num(row['longitude'] ?? row['lng']);
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      parsed.add(TrailPoint(
        point: ll.LatLng(lat, lng),
        time: _time(row),
        accuracyMeters: _num(row['accuracyMeters'] ?? row['accuracy']) ?? 0,
        insideCampus: row['insideCampus'] is bool ? row['insideCampus'] as bool : null,
        mocked: row['mocked'] == true,
      ));
    }

    // Only reorder when every row says when it happened; otherwise trust the API order.
    if (parsed.isNotEmpty && parsed.every((p) => p.time != null)) {
      parsed.sort((a, b) => a.time!.compareTo(b.time!));
    }

    final kept = <TrailPoint>[];
    for (final p in parsed) {
      if (kept.isNotEmpty && _distance.as(ll.LengthUnit.Meter, kept.last.point, p.point) < minStepMeters) {
        // Same spot: keep the first position, but carry the latest time forward.
        kept[kept.length - 1] = TrailPoint(
          point: kept.last.point,
          time: p.time ?? kept.last.time,
          accuracyMeters: p.accuracyMeters,
          insideCampus: p.insideCampus,
          mocked: kept.last.mocked || p.mocked,
        );
        continue;
      }
      kept.add(p);
    }
    return LocationTrail._(List.unmodifiable(kept));
  }

  bool get isEmpty => points.isEmpty;
  bool get hasPath => points.length >= 2;
  List<ll.LatLng> get latLngs => [for (final p in points) p.point];

  double get distanceMeters {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _distance.as(ll.LengthUnit.Meter, points[i - 1].point, points[i].point);
    }
    return total;
  }

  /// Time between the first and last fix, when the rows carry times.
  Duration? get span {
    final first = points.isEmpty ? null : points.first.time;
    final last = points.isEmpty ? null : points.last.time;
    return first == null || last == null ? null : last.difference(first);
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _time(Map<String, dynamic> row) {
    for (final key in _timeKeys) {
      final v = row[key];
      final n = _num(v);
      if (n != null) {
        // Seconds vs milliseconds since epoch.
        return DateTime.fromMillisecondsSinceEpoch(n > 100000000000 ? n.toInt() : (n * 1000).toInt());
      }
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed.toLocal();
      }
    }
    return null;
  }
}
