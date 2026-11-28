import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/features/geofence/utils/location_accuracy.dart';

/// The map's accuracy circle and the student location card's accuracy pill
/// must agree on what a given radius means -- they share this one source now
/// instead of each having their own copy of the thresholds.
void main() {
  test('percentage: a tighter radius means a higher score', () {
    expect(LocationAccuracy.percentage(0), 100);
    expect(LocationAccuracy.percentage(5), 98);
    expect(LocationAccuracy.percentage(75), 50);
    expect(LocationAccuracy.percentage(200), lessThan(50));
  });

  test('percentage never exceeds 100 or drops below 10', () {
    for (final m in [0.0, 1.0, 74.0, 76.0, 500.0, 5000.0]) {
      final pct = LocationAccuracy.percentage(m);
      expect(pct, inInclusiveRange(10, 100));
    }
  });

  test('color matches the accent in palette for the same radius', () {
    for (final m in [2.0, 20.0, 60.0, 150.0]) {
      final (accent, _, _) = LocationAccuracy.palette(m);
      expect(LocationAccuracy.color(m), accent);
    }
  });

  test('a fix at the breach-detection cutoff (75m) is "ok", not "good"', () {
    // GeofenceEvaluator.MAX_ACCURACY_M on the native side is 75 -- a fix this
    // coarse is the worst one the breach logic still accepts, so it should
    // never read as a confident, "good" fix here.
    expect(LocationAccuracy.percentage(75), lessThan(85));
  });
}
