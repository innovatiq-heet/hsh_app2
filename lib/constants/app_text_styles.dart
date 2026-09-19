import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base =>
      GoogleFonts.plusJakartaSans(color: AppColors.textPrimary);

  /// Tabular figures keep digit widths fixed, so animated counters don't
  /// jitter horizontally while ticking.
  static TextStyle numeric(double size, {FontWeight weight = FontWeight.w800}) =>
      _base.copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get displayXl => _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  );
  static TextStyle get displayLg => _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );
  static TextStyle get displayMd => _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static TextStyle get headline => _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static TextStyle get title =>
      _base.copyWith(fontSize: 17, fontWeight: FontWeight.w700);
  static TextStyle get subtitle =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  static TextStyle get bodyLg =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w500);
  static TextStyle get bodyMd =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle get bodySm => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get label => _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
  static TextStyle get caption => _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
  );
  static TextStyle get overline => _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 1.1,
  );

  static TextStyle get button => _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}
