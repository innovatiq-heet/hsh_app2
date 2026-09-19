import 'package:flutter/material.dart';

/// Design system color tokens (spec §4). The spec's brand hex values are
/// unchanged; everything below them is a derived supporting token for the
/// aurora / glass / depth treatment.
class AppColors {
  AppColors._();

  // --- Spec brand tokens (unchanged) ---
  static const Color headerBlue = Color(0xFF0F172A);
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color mainBackground = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color cancelledRed = Color(0xFFEF4444);
  static const Color pendingBlue = Color(0xFF3B82F6);

  // --- Supporting surface tokens ---
  static const Color border = Color(0xFFE2E8F0);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color primarySoft = Color(0xFFE8EEFB);
  static const Color shadow = Color(0xFF0F172A);

  // --- Aurora palette ---
  static const Color deepSlate = Color(0xFF0B0F19);
  static const Color indigo = Color(0xFF6366F1);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF22D3EE);

  // --- Glass ---
  static const Color glassFill = Color(0x1AFFFFFF); // white 10%
  static const Color glassBorder = Color(0x26FFFFFF); // white 15%

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Base wash under the aurora blobs; also the static fallback.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepSlate, primary, primaryLight],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, indigo, primaryLight],
    stops: [0.0, 0.55, 1.0],
  );

  /// Hairline gradient used as a card border for layered depth.
  static const LinearGradient cardBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0), Color(0xFFDDE3F5)],
  );

  static final List<BoxShadow> softShadow = tintedShadow(primary, 0.07);

  /// Two-layer ambient shadow tinted by [color] — a tight contact shadow
  /// plus a wide soft one — which reads as depth rather than grey smudge.
  static List<BoxShadow> tintedShadow(Color color, [double strength = 0.12]) => [
    BoxShadow(
      color: color.withValues(alpha: strength * 0.6),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: color.withValues(alpha: strength),
      blurRadius: 28,
      spreadRadius: -4,
      offset: const Offset(0, 14),
    ),
  ];

  static List<BoxShadow> glow(Color color, [double strength = 0.45]) => [
    BoxShadow(
      color: color.withValues(alpha: strength),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];
}
