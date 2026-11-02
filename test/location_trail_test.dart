import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/models/geofence/location_trail.dart';

Map<String, dynamic> _row(double lat, double lng, [Object? time]) =>
    {'latitude': lat, 'longitude': lng, 'fixTime': ?time};

void main() {
  test('sorts oldest to newest when every row has a time', () {
    final trail = LocationTrail.parse([
      _row(22.5600, 72.9200, 3000000000000),
      _row(22.5570, 72.9190, 1000000000000),
      _row(22.5580, 72.9195, 2000000000000),
    ]);
    expect(trail.points.map((p) => p.point.latitude), [22.5570, 22.5580, 22.5600]);
  });

  test('keeps API order when rows carry no time', () {
    final trail = LocationTrail.parse([_row(22.5570, 72.9190), _row(22.5600, 72.9200)]);
    expect(trail.points.first.point.latitude, 22.5570);
  });

  test('drops empty coordinates and jitter within the minimum step', () {
    final trail = LocationTrail.parse([
      _row(0, 0),
      _row(22.5570, 72.9190),
      _row(22.55701, 72.91901),
      _row(22.5600, 72.9200),
    ]);
    expect(trail.points.length, 2);
    expect(trail.hasPath, isTrue);
    expect(trail.distanceMeters, greaterThan(300));
  });

  test('reads seconds, milliseconds and ISO strings', () {
    final trail = LocationTrail.parse([
      _row(22.5570, 72.9190, 1700000000),
      _row(22.5600, 72.9200, '2023-11-14T22:30:00Z'),
    ]);
    expect(trail.points.every((p) => p.time != null), isTrue);
    expect(trail.span, isNotNull);
  });

  test('a single fix is not a path', () {
    expect(LocationTrail.parse([_row(22.5570, 72.9190)]).hasPath, isFalse);
    expect(LocationTrail.parse(const []).isEmpty, isTrue);
  });
}
