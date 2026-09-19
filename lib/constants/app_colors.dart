import 'package:flutter/material.dart';

/// Design system color tokens (spec §4). The spec's brand hex values are
/// unchanged; the soft tints, gradients and shadow below are derived
/// supporting tokens for the modern surface treatment.
class AppColors {
  AppColors._();

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

  static const Color border = Color(0xFFE2E8F0);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color primarySoft = Color(0xFFE8EEFB);
  static const Color shadow = Color(0xFF0F172A);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Hero headers: deep navy into brand blue.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerBlue, primary, primaryLight],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryLight],
  );

  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: shadow.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
