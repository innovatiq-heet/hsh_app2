import 'package:flutter/material.dart';

/// Turns a raw GPS accuracy radius (meters) into the same "how much to trust
/// this fix" scale used by both the student location card and the campus
/// map's accuracy circle, so the two always agree.
class LocationAccuracy {
  LocationAccuracy._();

  /// A rough 0-100 "confidence" score from an accuracy radius in meters.
  /// Not a real statistical percentage — just a readable stand-in for the
  /// radius, matching the thresholds `GeofenceEvaluator.MAX_ACCURACY_M` (75m)
  /// treats as the edge of "too coarse to trust".
  static int percentage(double accuracyMeters) {
    if (accuracyMeters <= 0) return 100;
    if (accuracyMeters <= 3) return 100;
    if (accuracyMeters <= 5) return 98;
    if (accuracyMeters <= 10) return 94;
    if (accuracyMeters <= 15) return 89;
    if (accuracyMeters <= 20) return 84;
    if (accuracyMeters <= 30) return 76;
    if (accuracyMeters <= 50) return 64;
    if (accuracyMeters <= 75) return 50;
    if (accuracyMeters <= 100) return 35;
    return (100 - (accuracyMeters * 0.75)).clamp(10.0, 30.0).round();
  }

  /// The single accent color for an accuracy level (good/ok/poor/bad).
  static Color color(double accuracyMeters) {
    final pct = percentage(accuracyMeters);
    if (pct >= 85) return const Color(0xFF16A34A);
    if (pct >= 65) return const Color(0xFF0284C7);
    if (pct >= 45) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  /// (accent, background, border) — the tri-color scheme the location card
  /// uses for its accuracy pill.
  static (Color, Color, Color) palette(double accuracyMeters) {
    final pct = percentage(accuracyMeters);
    if (pct >= 85) return (const Color(0xFF16A34A), const Color(0xFFF0FDF4), const Color(0xFFBBF7D0));
    if (pct >= 65) return (const Color(0xFF0284C7), const Color(0xFFE0F2FE), const Color(0xFFBAE6FD));
    if (pct >= 45) return (const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A));
    return (const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECDD3));
  }
}
