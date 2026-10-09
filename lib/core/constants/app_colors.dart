import 'package:flutter/material.dart';

/// Design system color tokens.
/// Modern academic & hospitality palette:
/// - Navy & Blue primary tones (#376682, #4D89A3)
/// - Warm Sand & Amber secondary accents (#EAAB78, #8A5A1F)
/// - Cream background (#F6F4EF)
/// - Deep Ink charcoal text (#22333C)
/// - Subtle Line borders (#E4E1DA)
class AppColors {
  AppColors._();

  // --- Main brand colors ---
  /// Navy / Primary: #376682
  static const Color primary = Color.fromARGB(255, 86, 156, 196);

  /// Blue / Primary Light: #4D89A3
  static const Color primaryLight = Color(0xFF4D89A3);

  /// Ink / Primary Dark: #22333C
  static const Color primaryDark = Color(0xFF22333C);

  /// Header tint: #376682
  static const Color headerBlue = Color(0xFF376682);

  /// Warm sand / Secondary: #EAAB78
  static const Color secondary = Color(0xFFEAAB78);

  /// Sand light: #F3C9A6
  static const Color secondaryLight = Color(0xFFF3C9A6);

  /// Amber dark: #8A5A1F
  static const Color secondaryDark = Color(0xFF8A5A1F);

  /// Ink / Accent: #22333C
  static const Color accent = Color(0xFF22333C);

  /// Mist / Accent Light: #769BAB
  static const Color accentLight = Color(0xFF769BAB);

  /// Charcoal dark: #18252C
  static const Color accentDark = Color(0xFF18252C);

  // --- Backgrounds ---
  /// Warm cream background: #F6F4EF
  static const Color mainBackground = Color(0xFFF6F4EF);

  /// Background secondary: #FAF9F6
  static const Color backgroundSecondary = Color(0xFFFAF9F6);

  /// White surface: #FFFFFF
  static const Color surface = Color(0xFFFFFFFF);

  /// Surface muted: #F6F4EF
  static const Color surfaceMuted = Color(0xFFF6F4EF);

  // --- Text ---
  /// Primary text: #22333C
  static const Color textPrimary = Color(0xFF22333C);

  /// Secondary text: #5D6B73
  static const Color textSecondary = Color(0xFF5D6B73);

  /// Muted text: #94938E
  static const Color textMuted = Color(0xFF94938E);

  /// Light text: #B0B5B9
  static const Color textLight = Color(0xFFB0B5B9);

  // --- Borders ---
  /// Border: #E4E1DA
  static const Color border = Color(0xFFE4E1DA);

  /// Border light: #ECEAE4
  static const Color borderLight = Color(0xFFECEAE4);

  /// Border primary: #4D89A3
  static const Color borderPrimary = Color(0xFF4D89A3);

  /// Border accent: #769BAB
  static const Color borderAccent = Color(0xFF769BAB);

  // --- Status colors ---
  /// Success: #2E7D32
  static const Color successGreen = Color(0xFF2E7D32);

  /// Warning: #8A5A1F
  static const Color warningOrange = Color(0xFF8A5A1F);

  /// Error: #D32F2F
  static const Color cancelledRed = Color(0xFFD32F2F);
  static const Color errorRed = Color(0xFFD32F2F);

  /// Info / Pending: #4D89A3
  static const Color pendingBlue = Color(0xFF4D89A3);

  // --- Supporting tokens ---
  /// Soft navy tint for badges, selected pills & wash surfaces
  static const Color primarySoft = Color(0xFFEBF2F5);

  /// Soft sand tint
  static const Color secondarySoft = Color(0xFFFDF4EC);

  /// Warm shadow
  static const Color shadow = Color(0xFF22333C);

  // --- Gradients ---
  /// Navy into Blue
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  /// Hero headers: deep ink into navy and blue
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
    stops: [0.0, 0.55, 1.0],
  );

  /// Buttons: navy into blue
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryLight],
  );

  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: shadow.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
