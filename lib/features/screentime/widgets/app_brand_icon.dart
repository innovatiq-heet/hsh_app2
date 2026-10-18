import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/app_icon_cache.dart';

/// App icon for parental-control and screen-time lists.
///
/// Shows the app's real launcher icon when the student's device has uploaded
/// it (see [AppIconCache]); otherwise displays an authentic, pixel-perfect,
/// realistic brand icon custom-rendered to match official launcher icons.
class AppBrandIcon extends StatelessWidget {
  final String packageName;
  final String appName;
  final double size;
  final bool isBlocked;
  final bool showBadge;

  const AppBrandIcon({
    super.key,
    required this.packageName,
    required this.appName,
    this.size = 44.0,
    this.isBlocked = false,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppIconCache.revision,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.24);
    final realIcon = AppIconCache.get(packageName);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (realIcon != null)
            ClipRRect(
              borderRadius: borderRadius,
              child: Image.memory(
                realIcon,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _realisticPlaceholder(borderRadius),
              ),
            )
          else
            _realisticPlaceholder(borderRadius),

          if (isBlocked && showBadge)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: EdgeInsets.all(size * 0.07),
                decoration: BoxDecoration(
                  color: AppColors.cancelledRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.block_rounded,
                  size: size * 0.28,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _realisticPlaceholder(BorderRadius borderRadius) {
    final brand = _resolveBrand(packageName, appName);
    return _buildBrandWidget(brand, borderRadius);
  }

  Widget _buildBrandWidget(_BrandType brand, BorderRadius borderRadius) {
    switch (brand) {
      case _BrandType.instagram:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF833AB4),
              Color(0xFFC13584),
              Color(0xFFE1306C),
              Color(0xFFFD1D1D),
              Color(0xFFF56040),
              Color(0xFFFCAF45),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          child: CustomPaint(painter: _InstagramPainter()),
        );

      case _BrandType.youtube:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF0000), Color(0xFFD30000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          child: CustomPaint(painter: _YouTubePainter()),
        );

      case _BrandType.whatsapp:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          child: CustomPaint(painter: _WhatsAppPainter()),
        );

      case _BrandType.bookMyShow:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFFE51937), Color(0xFFB8132A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _BookMyShowPainter()),
        );

      case _BrandType.googleMaps:
        return _brandContainer(
          borderRadius: borderRadius,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          child: CustomPaint(painter: _GoogleMapsPainter()),
        );

      case _BrandType.hariPrabodham:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _HariPrabodhamPainter()),
        );

      case _BrandType.phoneManager:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _PhoneManagerPainter()),
        );

      case _BrandType.chrome:
        return _brandContainer(
          borderRadius: borderRadius,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          child: CustomPaint(painter: _ChromePainter()),
        );

      case _BrandType.snapchat:
        return _brandContainer(
          borderRadius: borderRadius,
          color: const Color(0xFFFFFC00),
          child: CustomPaint(painter: _SnapchatPainter()),
        );

      case _BrandType.spotify:
        return _brandContainer(
          borderRadius: borderRadius,
          color: const Color(0xFF191414),
          child: CustomPaint(painter: _SpotifyPainter()),
        );

      case _BrandType.netflix:
        return _brandContainer(
          borderRadius: borderRadius,
          color: const Color(0xFF000000),
          child: CustomPaint(painter: _NetflixPainter()),
        );

      case _BrandType.telegram:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _TelegramPainter()),
        );

      case _BrandType.twitterX:
        return _brandContainer(
          borderRadius: borderRadius,
          color: const Color(0xFF000000),
          child: CustomPaint(painter: _TwitterXPainter()),
        );

      case _BrandType.facebook:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF1877F2), Color(0xFF0D65D9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          child: CustomPaint(painter: _FacebookPainter()),
        );

      case _BrandType.discord:
        return _brandContainer(
          borderRadius: borderRadius,
          color: const Color(0xFF5865F2),
          child: CustomPaint(painter: _DiscordPainter()),
        );

      case _BrandType.reddit:
        return _brandContainer(
          borderRadius: borderRadius,
          color: const Color(0xFFFF4500),
          child: CustomPaint(painter: _RedditPainter()),
        );

      case _BrandType.phonePe:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF5F259F), Color(0xFF4D148C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Center(
            child: Text(
              'पे',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.48,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
        );

      case _BrandType.googlePay:
        return _brandContainer(
          borderRadius: borderRadius,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          child: CustomPaint(painter: _GooglePayPainter()),
        );

      case _BrandType.amazon:
        return _brandContainer(
          borderRadius: borderRadius,
          color: const Color(0xFF232F3E),
          child: CustomPaint(painter: _AmazonPainter()),
        );

      case _BrandType.flipkart:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF2874F0), Color(0xFF0C51C4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _FlipkartPainter()),
        );

      case _BrandType.camera:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF334155), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _CameraPainter()),
        );

      case _BrandType.gallery:
        return _brandContainer(
          borderRadius: borderRadius,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          child: CustomPaint(painter: _GalleryPainter()),
        );

      case _BrandType.settings:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF64748B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _SettingsPainter()),
        );

      case _BrandType.phone:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Center(
            child: Icon(Icons.phone_rounded, color: Colors.white, size: size * 0.54),
          ),
        );

      case _BrandType.messages:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Center(
            child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: size * 0.52),
          ),
        );

      case _BrandType.clock:
        return _brandContainer(
          borderRadius: borderRadius,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          child: CustomPaint(painter: _ClockPainter()),
        );

      case _BrandType.calculator:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: CustomPaint(painter: _CalculatorPainter()),
        );

      case _BrandType.files:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Center(
            child: Icon(Icons.folder_rounded, color: Colors.white, size: size * 0.54),
          ),
        );

      case _BrandType.gmail:
        return _brandContainer(
          borderRadius: borderRadius,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          child: Center(
            child: Icon(Icons.mail_rounded, color: const Color(0xFFEA4335), size: size * 0.52),
          ),
        );

      case _BrandType.game:
        return _brandContainer(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Center(
            child: Icon(Icons.sports_esports_rounded, color: Colors.white, size: size * 0.54),
          ),
        );

      case _BrandType.generic:
        return _genericTile(borderRadius);
    }
  }

  Widget _brandContainer({
    required BorderRadius borderRadius,
    Color? color,
    Gradient? gradient,
    BoxBorder? border,
    required Widget child,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: borderRadius,
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }

  Widget _genericTile(BorderRadius borderRadius) {
    final hash = (packageName.isNotEmpty ? packageName : appName).hashCode.abs();
    final palettes = [
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
      [const Color(0xFF2563EB), const Color(0xFF38BDF8)],
      [const Color(0xFF059669), const Color(0xFF10B981)],
      [const Color(0xFFD97706), const Color(0xFFF59E0B)],
      [const Color(0xFFDC2626), const Color(0xFFEF4444)],
      [const Color(0xFF7C3AED), const Color(0xFFC084FC)],
      [const Color(0xFF0891B2), const Color(0xFF06B6D4)],
      [const Color(0xFFEA580C), const Color(0xFFFB923C)],
    ];
    final selectedPalette = palettes[hash % palettes.length];
    final letter = _getFallbackLetter(appName, packageName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selectedPalette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: selectedPalette.first.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle top-edge glossy highlight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size * 0.38,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: borderRadius.topLeft),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.44,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _getFallbackLetter(String name, String pkg) {
    if (name.isNotEmpty && name.trim().isNotEmpty) {
      return name.trim()[0].toUpperCase();
    }
    final parts = pkg.split('.');
    if (parts.isNotEmpty && parts.last.isNotEmpty) {
      return parts.last[0].toUpperCase();
    }
    return 'A';
  }

  static _BrandType _resolveBrand(String rawPkg, String rawName) {
    final pkg = rawPkg.toLowerCase().trim();
    final name = rawName.toLowerCase().trim();

    // 1. YouTube
    if (pkg.contains('youtube') || name.contains('youtube')) {
      return _BrandType.youtube;
    }

    // 2. Instagram
    if (pkg.contains('instagram') || name.contains('instagram')) {
      return _BrandType.instagram;
    }

    // 3. WhatsApp
    if (pkg.contains('whatsapp') || name.contains('whatsapp')) {
      return _BrandType.whatsapp;
    }

    // 4. BookMyShow
    if (pkg.contains('bms') ||
        name.contains('bookmyshow') ||
        name.contains('book my show') ||
        pkg.contains('com.bt.bms')) {
      return _BrandType.bookMyShow;
    }

    // 5. Google Maps
    if (pkg.contains('apps.maps') ||
        pkg.contains('google.android.apps.maps') ||
        name == 'maps' ||
        name == 'google maps' ||
        name.contains('maps')) {
      return _BrandType.googleMaps;
    }

    // 6. HariPrabodham (Hostel Satsang app)
    if (pkg.contains('hariprabodham') ||
        name.contains('hariprabodha') ||
        name.contains('hari prabodha') ||
        name.contains('haridham') ||
        pkg.contains('apnc')) {
      return _BrandType.hariPrabodham;
    }

    // 7. Phone Manager / System Cleaner
    if (pkg.contains('phonemanager') ||
        pkg.contains('phone_manager') ||
        name.contains('phone manager') ||
        name.contains('phone manag') ||
        name.contains('device care') ||
        pkg.contains('cleanmaster') ||
        pkg.contains('security')) {
      return _BrandType.phoneManager;
    }

    // 8. Google Chrome
    if (pkg.contains('chrome') || name.contains('chrome')) {
      return _BrandType.chrome;
    }

    // 9. Snapchat
    if (pkg.contains('snapchat') || name.contains('snapchat')) {
      return _BrandType.snapchat;
    }

    // 10. Spotify
    if (pkg.contains('spotify') || name.contains('spotify')) {
      return _BrandType.spotify;
    }

    // 11. Netflix
    if (pkg.contains('netflix') || name.contains('netflix')) {
      return _BrandType.netflix;
    }

    // 12. Telegram
    if (pkg.contains('telegram') || name.contains('telegram')) {
      return _BrandType.telegram;
    }

    // 13. Twitter / X
    if (pkg.contains('twitter') || name == 'x' || name.contains('twitter')) {
      return _BrandType.twitterX;
    }

    // 14. Facebook
    if (pkg.contains('facebook') || name.contains('facebook') || pkg.contains('katana')) {
      return _BrandType.facebook;
    }

    // 15. Discord
    if (pkg.contains('discord') || name.contains('discord')) {
      return _BrandType.discord;
    }

    // 16. Reddit
    if (pkg.contains('reddit') || name.contains('reddit')) {
      return _BrandType.reddit;
    }

    // 17. PhonePe
    if (pkg.contains('phonepe') || name.contains('phonepe') || name.contains('phone pe')) {
      return _BrandType.phonePe;
    }

    // 18. Google Pay
    if (pkg.contains('google.android.apps.nbu.paisa') ||
        pkg.contains('gpay') ||
        name.contains('gpay') ||
        name.contains('google pay')) {
      return _BrandType.googlePay;
    }

    // 19. Amazon
    if (pkg.contains('amazon') || name.contains('amazon')) {
      return _BrandType.amazon;
    }

    // 20. Flipkart
    if (pkg.contains('flipkart') || name.contains('flipkart')) {
      return _BrandType.flipkart;
    }

    // 21. Camera
    if (pkg.contains('camera') || name == 'camera') {
      return _BrandType.camera;
    }

    // 22. Gallery / Photos
    if (pkg.contains('gallery') || name.contains('gallery') || name == 'photos') {
      return _BrandType.gallery;
    }

    // 23. Settings
    if (pkg.contains('settings') || name == 'settings') {
      return _BrandType.settings;
    }

    // 24. Phone / Dialer
    if (pkg.contains('dialer') || name == 'phone' || pkg.contains('telecom')) {
      return _BrandType.phone;
    }

    // 25. Messages / SMS
    if (pkg.contains('messaging') || name.contains('message') || pkg.contains('mms')) {
      return _BrandType.messages;
    }

    // 26. Clock
    if (pkg.contains('deskclock') || name == 'clock' || name.contains('alarm')) {
      return _BrandType.clock;
    }

    // 27. Calculator
    if (pkg.contains('calculator') || name.contains('calculator')) {
      return _BrandType.calculator;
    }

    // 28. Files
    if (pkg.contains('documentsui') || name.contains('files') || name.contains('file manager')) {
      return _BrandType.files;
    }

    // 29. Gmail
    if (pkg.contains('gmail') || name.contains('gmail')) {
      return _BrandType.gmail;
    }

    // 30. Games
    if (pkg.contains('game') ||
        name.contains('game') ||
        pkg.contains('freefire') ||
        pkg.contains('pubg') ||
        pkg.contains('bgmi') ||
        pkg.contains('roblox') ||
        pkg.contains('mojang') ||
        pkg.contains('clash') ||
        name.contains('candy crush')) {
      return _BrandType.game;
    }

    return _BrandType.generic;
  }
}

enum _BrandType {
  instagram,
  youtube,
  whatsapp,
  bookMyShow,
  googleMaps,
  hariPrabodham,
  phoneManager,
  chrome,
  snapchat,
  spotify,
  netflix,
  telegram,
  twitterX,
  facebook,
  discord,
  reddit,
  phonePe,
  googlePay,
  amazon,
  flipkart,
  camera,
  gallery,
  settings,
  phone,
  messages,
  clock,
  calculator,
  files,
  gmail,
  game,
  generic,
}

// -------------------------------------------------------------
// Pixel-Perfect Vector Painters for Realistic Icons
// -------------------------------------------------------------

/// Official Instagram squircle with lens ring and flash dot.
class _InstagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.082;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 1. Outer squircle
    final outerPadding = size.width * 0.17;
    final outerRect = Rect.fromLTWH(
      outerPadding,
      outerPadding,
      size.width - outerPadding * 2,
      size.height - outerPadding * 2,
    );
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      Radius.circular(size.width * 0.19),
    );
    canvas.drawRRect(outerRRect, strokePaint);

    // 2. Center lens circle
    final center = Offset(size.width / 2, size.height / 2);
    final lensRadius = size.width * 0.165;
    canvas.drawCircle(center, lensRadius, strokePaint);

    // 3. Flash dot at top right
    final dotCenter = Offset(size.width * 0.69, size.height * 0.31);
    final dotRadius = size.width * 0.046;
    canvas.drawCircle(dotCenter, dotRadius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official YouTube play triangle.
class _YouTubePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.39, h * 0.30)
      ..lineTo(w * 0.70, h * 0.50)
      ..lineTo(w * 0.39, h * 0.70)
      ..close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official WhatsApp speech bubble with pointer tail and angled telephone handset.
class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. White speech bubble with pointer tail
    final bubblePath = Path();
    final bubbleRadius = w * 0.32;
    final center = Offset(w * 0.50, h * 0.48);

    bubblePath.addArc(
      Rect.fromCircle(center: center, radius: bubbleRadius),
      -0.6,
      5.2,
    );
    bubblePath.lineTo(w * 0.22, h * 0.80);
    bubblePath.close();

    canvas.drawPath(
      bubblePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // 2. Green phone handset inside bubble
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.phone.codePoint),
        style: TextStyle(
          inherit: false,
          color: const Color(0xFF25D366),
          fontSize: w * 0.36,
          fontFamily: Icons.phone.fontFamily,
          package: Icons.phone.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(w * 0.50, h * 0.47);
    canvas.rotate(-0.55);
    iconPainter.paint(
      canvas,
      Offset(-iconPainter.width / 2, -iconPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official BookMyShow crimson ticket with side notches and bold "bms" text.
class _BookMyShowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // White cinema ticket badge
    final ticketRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.5),
      width: w * 0.72,
      height: h * 0.50,
    );
    final ticketPath = Path()
      ..addRRect(RRect.fromRectAndRadius(ticketRect, Radius.circular(w * 0.08)));

    final notchRadius = w * 0.07;
    final leftNotch = Path()
      ..addOval(Rect.fromCircle(center: Offset(ticketRect.left, ticketRect.center.dy), radius: notchRadius));
    final rightNotch = Path()
      ..addOval(Rect.fromCircle(center: Offset(ticketRect.right, ticketRect.center.dy), radius: notchRadius));

    final finalTicket = Path.combine(PathOperation.difference, ticketPath, leftNotch);
    final ticketWithBothNotches = Path.combine(PathOperation.difference, finalTicket, rightNotch);

    canvas.drawPath(ticketWithBothNotches, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // "bms" logo typography inside ticket
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'bms',
        style: TextStyle(
          color: const Color(0xFFE51937),
          fontSize: w * 0.23,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, (h - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Google Maps 4-color location pin.
class _GoogleMapsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final headCenter = Offset(w * 0.50, h * 0.38);
    final headRadius = w * 0.21;

    // 1. Red top arch
    final redPath = Path()
      ..arcTo(
        Rect.fromCircle(center: headCenter, radius: headRadius),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill);

    // 2. Green right curve
    final greenPath = Path()
      ..moveTo(headCenter.dx + headRadius, headCenter.dy)
      ..cubicTo(
        headCenter.dx + headRadius, headCenter.dy + headRadius * 0.7,
        headCenter.dx + headRadius * 0.3, h * 0.65,
        headCenter.dx, h * 0.82,
      )
      ..lineTo(headCenter.dx, headCenter.dy)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill);

    // 3. Blue left curve
    final bluePath = Path()
      ..moveTo(headCenter.dx - headRadius, headCenter.dy)
      ..cubicTo(
        headCenter.dx - headRadius, headCenter.dy + headRadius * 0.7,
        headCenter.dx - headRadius * 0.3, h * 0.65,
        headCenter.dx, h * 0.82,
      )
      ..lineTo(headCenter.dx, headCenter.dy)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill);

    // 4. Yellow highlight at bottom tip
    final yellowPath = Path()
      ..moveTo(headCenter.dx - headRadius * 0.25, h * 0.73)
      ..lineTo(headCenter.dx, h * 0.82)
      ..lineTo(headCenter.dx + headRadius * 0.25, h * 0.73)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill);

    // 5. Center cutout hole
    canvas.drawCircle(
      headCenter,
      headRadius * 0.42,
      Paint()..color = const Color(0xFFB31412)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Authentic Swaminarayan Tilak-Chandlo for HariPrabodham app.
class _HariPrabodhamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);

    // 1. Radiant divine aura halo
    canvas.drawCircle(
      center,
      w * 0.37,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    // 2. Sacred Golden U-shaped Tilak
    final tilakPath = Path();
    final topY = h * 0.20;
    final bottomY = h * 0.73;
    final leftX = w * 0.33;
    final rightX = w * 0.67;

    tilakPath.moveTo(leftX, topY);
    tilakPath.lineTo(leftX, bottomY - h * 0.16);
    tilakPath.cubicTo(
      leftX, bottomY,
      rightX, bottomY,
      rightX, bottomY - h * 0.16,
    );
    tilakPath.lineTo(rightX, topY);

    canvas.drawPath(
      tilakPath,
      Paint()
        ..color = const Color(0xFFFFF9C4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.088
        ..strokeCap = StrokeCap.round,
    );

    // 3. Auspicious Crimson Red Chandlo (Center Bindu)
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.48),
      w * 0.105,
      Paint()
        ..color = const Color(0xFFB71C1C)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Electric cyan security shield with speed checkmark for Phone Manager.
class _PhoneManagerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shield path
    final shield = Path()
      ..moveTo(w * 0.50, h * 0.18)
      ..lineTo(w * 0.78, h * 0.28)
      ..cubicTo(
        w * 0.78, h * 0.56,
        w * 0.62, h * 0.74,
        w * 0.50, h * 0.82,
      )
      ..cubicTo(
        w * 0.38, h * 0.74,
        w * 0.22, h * 0.56,
        w * 0.22, h * 0.28,
      )
      ..close();

    // Semi-transparent shield body
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    // Shield outline
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.065
        ..strokeJoin = StrokeJoin.round,
    );

    // Speed checkmark
    final check = Path()
      ..moveTo(w * 0.38, h * 0.49)
      ..lineTo(w * 0.47, h * 0.59)
      ..lineTo(w * 0.65, h * 0.39);

    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Google Chrome 4-color spinner.
class _ChromePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final radius = w * 0.38;

    // Red sector (top)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.0944,
      2.0944,
      true,
      Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill,
    );
    // Green sector (bottom-left)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.0944,
      2.0944,
      true,
      Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill,
    );
    // Yellow sector (bottom-right)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.0,
      2.0944,
      true,
      Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill,
    );

    // White circle separator
    canvas.drawCircle(
      center,
      radius * 0.50,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );

    // Blue center core
    canvas.drawCircle(
      center,
      radius * 0.40,
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Snapchat ghost silhouette.
class _SnapchatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final ghost = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..cubicTo(w * 0.65, h * 0.22, w * 0.69, h * 0.34, w * 0.69, h * 0.46)
      ..cubicTo(w * 0.77, h * 0.47, w * 0.81, h * 0.52, w * 0.79, h * 0.57)
      ..cubicTo(w * 0.76, h * 0.61, w * 0.70, h * 0.58, w * 0.68, h * 0.56)
      ..cubicTo(w * 0.68, h * 0.68, w * 0.77, h * 0.74, w * 0.73, h * 0.78)
      ..cubicTo(w * 0.68, h * 0.82, w * 0.62, h * 0.75, w * 0.50, h * 0.78)
      ..cubicTo(w * 0.38, h * 0.75, w * 0.32, h * 0.82, w * 0.27, h * 0.78)
      ..cubicTo(w * 0.23, h * 0.74, w * 0.32, h * 0.68, w * 0.32, h * 0.56)
      ..cubicTo(w * 0.30, h * 0.58, w * 0.24, h * 0.61, w * 0.21, h * 0.57)
      ..cubicTo(w * 0.19, h * 0.52, w * 0.23, h * 0.47, w * 0.31, h * 0.46)
      ..cubicTo(w * 0.31, h * 0.34, w * 0.35, h * 0.22, w * 0.50, h * 0.22)
      ..close();

    // White body
    canvas.drawPath(ghost, Paint()..color = Colors.white..style = PaintingStyle.fill);
    // Dark outline
    canvas.drawPath(
      ghost,
      Paint()
        ..color = const Color(0xFF1E1E1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Spotify curved sound waves.
class _SpotifyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green circle base
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.40,
      Paint()..color = const Color(0xFF1DB954)..style = PaintingStyle.fill,
    );

    // 3 Black curved sound waves
    final wavePaint = Paint()
      ..color = const Color(0xFF191414)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(-0.25);

    // Top wave
    wavePaint.strokeWidth = w * 0.082;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, h * 0.08), radius: w * 0.28),
      -math.pi * 0.74,
      math.pi * 0.48,
      false,
      wavePaint,
    );

    // Middle wave
    wavePaint.strokeWidth = w * 0.072;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, h * 0.05), radius: w * 0.21),
      -math.pi * 0.74,
      math.pi * 0.48,
      false,
      wavePaint,
    );

    // Bottom wave
    wavePaint.strokeWidth = w * 0.062;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, h * 0.02), radius: w * 0.14),
      -math.pi * 0.74,
      math.pi * 0.48,
      false,
      wavePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Netflix bold red "N" ribbon.
class _NetflixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Left vertical stem (dark red)
    canvas.drawRect(
      Rect.fromLTWH(w * 0.27, h * 0.18, w * 0.15, h * 0.64),
      Paint()..color = const Color(0xFFB81D24)..style = PaintingStyle.fill,
    );

    // Right vertical stem (dark red)
    canvas.drawRect(
      Rect.fromLTWH(w * 0.58, h * 0.18, w * 0.15, h * 0.64),
      Paint()..color = const Color(0xFFB81D24)..style = PaintingStyle.fill,
    );

    // Diagonal bright red ribbon with shadow
    final diagPath = Path()
      ..moveTo(w * 0.27, h * 0.18)
      ..lineTo(w * 0.42, h * 0.18)
      ..lineTo(w * 0.73, h * 0.82)
      ..lineTo(w * 0.58, h * 0.82)
      ..close();

    canvas.drawPath(
      diagPath,
      Paint()..color = const Color(0xFFE50914)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Telegram white paper airplane.
class _TelegramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final plane = Path()
      ..moveTo(w * 0.22, h * 0.48)
      ..lineTo(w * 0.78, h * 0.24)
      ..lineTo(w * 0.62, h * 0.76)
      ..lineTo(w * 0.48, h * 0.61)
      ..lineTo(w * 0.44, h * 0.72)
      ..lineTo(w * 0.41, h * 0.57)
      ..close();

    canvas.drawPath(plane, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Fold line
    final fold = Path()
      ..moveTo(w * 0.48, h * 0.61)
      ..lineTo(w * 0.78, h * 0.24);

    canvas.drawPath(
      fold,
      Paint()
        ..color = const Color(0xFF229ED9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Twitter/X modern white "𝕏" logo.
class _TwitterXPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '𝕏',
        style: TextStyle(
          color: Colors.white,
          fontSize: w * 0.56,
          fontWeight: FontWeight.w400,
          fontFamily: 'serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, (h - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Facebook bold white lower-case "f".
class _FacebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fPath = Path()
      ..moveTo(w * 0.68, h * 0.85)
      ..lineTo(w * 0.52, h * 0.85)
      ..lineTo(w * 0.52, h * 0.55)
      ..lineTo(w * 0.63, h * 0.55)
      ..lineTo(w * 0.66, h * 0.42)
      ..lineTo(w * 0.52, h * 0.42)
      ..lineTo(w * 0.52, h * 0.33)
      ..cubicTo(w * 0.52, h * 0.27, w * 0.55, h * 0.23, w * 0.63, h * 0.23)
      ..lineTo(w * 0.69, h * 0.23)
      ..lineTo(w * 0.69, h * 0.13)
      ..cubicTo(w * 0.63, h * 0.12, w * 0.56, h * 0.12, w * 0.49, h * 0.15)
      ..cubicTo(w * 0.40, h * 0.19, w * 0.37, h * 0.25, w * 0.37, h * 0.36)
      ..lineTo(w * 0.37, h * 0.42)
      ..lineTo(w * 0.26, h * 0.42)
      ..lineTo(w * 0.26, h * 0.55)
      ..lineTo(w * 0.37, h * 0.55)
      ..lineTo(w * 0.37, h * 0.85)
      ..close();

    canvas.drawPath(fPath, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Discord Clyde gamepad mascot.
class _DiscordPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final clyde = Path()
      ..moveTo(w * 0.26, h * 0.34)
      ..cubicTo(w * 0.38, h * 0.28, w * 0.62, h * 0.28, w * 0.74, h * 0.34)
      ..lineTo(w * 0.78, h * 0.58)
      ..cubicTo(w * 0.74, h * 0.64, w * 0.67, h * 0.68, w * 0.59, h * 0.70)
      ..lineTo(w * 0.55, h * 0.63)
      ..cubicTo(w * 0.52, h * 0.64, w * 0.48, h * 0.64, w * 0.45, h * 0.63)
      ..lineTo(w * 0.41, h * 0.70)
      ..cubicTo(w * 0.33, h * 0.68, w * 0.26, h * 0.64, w * 0.22, h * 0.58)
      ..close();

    canvas.drawPath(clyde, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Eye cutouts
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.38, h * 0.49), width: w * 0.10, height: h * 0.12),
      Paint()..color = const Color(0xFF5865F2)..style = PaintingStyle.fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.62, h * 0.49), width: w * 0.10, height: h * 0.12),
      Paint()..color = const Color(0xFF5865F2)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Reddit Snoo alien face.
class _RedditPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.54, height: h * 0.42),
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );

    // Orange eyes
    canvas.drawCircle(Offset(w * 0.41, h * 0.50), w * 0.055, Paint()..color = const Color(0xFFFF4500));
    canvas.drawCircle(Offset(w * 0.59, h * 0.50), w * 0.055, Paint()..color = const Color(0xFFFF4500));

    // Smile
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.54), width: w * 0.22, height: h * 0.16),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = const Color(0xFF1E1E1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.038
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Google Pay 4-color intertwined ribbon loop.
class _GooglePayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p1 = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = w * 0.08..strokeCap = StrokeCap.round;
    final p2 = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = w * 0.08..strokeCap = StrokeCap.round;
    final p3 = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = w * 0.08..strokeCap = StrokeCap.round;
    final p4 = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = w * 0.08..strokeCap = StrokeCap.round;

    final loop1 = Path()..moveTo(w * 0.28, h * 0.40)..cubicTo(w * 0.28, h * 0.28, w * 0.46, h * 0.28, w * 0.54, h * 0.42);
    final loop2 = Path()..moveTo(w * 0.54, h * 0.42)..cubicTo(w * 0.62, h * 0.56, w * 0.72, h * 0.56, w * 0.72, h * 0.40);
    final loop3 = Path()..moveTo(w * 0.72, h * 0.60)..cubicTo(w * 0.72, h * 0.72, w * 0.54, h * 0.72, w * 0.46, h * 0.58);
    final loop4 = Path()..moveTo(w * 0.46, h * 0.58)..cubicTo(w * 0.38, h * 0.44, w * 0.28, h * 0.44, w * 0.28, h * 0.60);

    canvas.drawPath(loop1, p1);
    canvas.drawPath(loop2, p2);
    canvas.drawPath(loop3, p3);
    canvas.drawPath(loop4, p4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Amazon orange smile curved arrow.
class _AmazonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // "a" letter
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'a',
        style: TextStyle(
          color: Colors.white,
          fontSize: w * 0.48,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.34, h * 0.16));

    // Orange smile arrow
    final smile = Path()
      ..moveTo(w * 0.25, h * 0.68)
      ..cubicTo(w * 0.42, h * 0.78, w * 0.62, h * 0.78, w * 0.74, h * 0.65);

    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFFFF9900)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.065
        ..strokeCap = StrokeCap.round,
    );

    // Arrow tip
    final arrow = Path()
      ..moveTo(w * 0.70, h * 0.61)
      ..lineTo(w * 0.78, h * 0.65)
      ..lineTo(w * 0.72, h * 0.73)
      ..close();

    canvas.drawPath(arrow, Paint()..color = const Color(0xFFFF9900)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Flipkart yellow shopping bag with blue "f".
class _FlipkartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Yellow shopping bag
    final bag = Path()
      ..moveTo(w * 0.28, h * 0.36)
      ..lineTo(w * 0.72, h * 0.36)
      ..lineTo(w * 0.68, h * 0.78)
      ..lineTo(w * 0.32, h * 0.78)
      ..close();

    canvas.drawPath(bag, Paint()..color = const Color(0xFFFFE500)..style = PaintingStyle.fill);

    // Bag handle
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.36), width: w * 0.26, height: h * 0.24),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055,
    );

    // "f" speed letter
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'f',
        style: TextStyle(
          color: const Color(0xFF2874F0),
          fontSize: w * 0.36,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.42, h * 0.39));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Camera lens rings with cyan glare.
class _CameraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Outer metallic ring
    canvas.drawCircle(
      center,
      w * 0.34,
      Paint()..color = const Color(0xFF475569)..style = PaintingStyle.stroke..strokeWidth = w * 0.065,
    );
    // Dark lens
    canvas.drawCircle(center, w * 0.28, Paint()..color = const Color(0xFF0F172A));
    // Inner cyan glass reflection
    canvas.drawCircle(
      Offset(center.dx - w * 0.08, center.dy - w * 0.08),
      w * 0.085,
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Colorful Gallery photo flower petals.
class _GalleryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final colors = [
      const Color(0xFFEA4335),
      const Color(0xFFFBBC05),
      const Color(0xFF34A853),
      const Color(0xFF4285F4),
    ];

    for (var i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final petalCenter = Offset(
        center.dx + math.cos(angle) * w * 0.15,
        center.dy + math.sin(angle) * w * 0.15,
      );
      canvas.drawCircle(
        petalCenter,
        w * 0.14,
        Paint()..color = colors[i].withValues(alpha: 0.88),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Precision Settings cogwheel.
class _SettingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Outer gear
    canvas.drawCircle(
      center,
      w * 0.28,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.11,
    );
    // Center hole
    canvas.drawCircle(
      center,
      w * 0.12,
      Paint()..color = const Color(0xFF334155),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Analog Clock dial with hour/minute and red second hand.
class _ClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Dial ring
    canvas.drawCircle(
      center,
      w * 0.36,
      Paint()..color = const Color(0xFF1E293B)..style = PaintingStyle.stroke..strokeWidth = w * 0.05,
    );

    // Minute hand (pointing to 2)
    canvas.drawLine(
      center,
      Offset(center.dx + w * 0.18, center.dy - w * 0.18),
      Paint()..color = const Color(0xFF1E293B)..strokeWidth = w * 0.055..strokeCap = StrokeCap.round,
    );

    // Hour hand (pointing to 10)
    canvas.drawLine(
      center,
      Offset(center.dx - w * 0.14, center.dy - w * 0.12),
      Paint()..color = const Color(0xFF1E293B)..strokeWidth = w * 0.075..strokeCap = StrokeCap.round,
    );

    // Red second hand
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy + w * 0.22),
      Paint()..color = const Color(0xFFEF4444)..strokeWidth = w * 0.035..strokeCap = StrokeCap.round,
    );

    // Center pin
    canvas.drawCircle(center, w * 0.045, Paint()..color = const Color(0xFFEF4444));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Calculator math grid symbols `+ − × =`.
class _CalculatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round;

    // + (top-left)
    canvas.drawLine(Offset(w * 0.28, w * 0.32), Offset(w * 0.42, w * 0.32), p);
    canvas.drawLine(Offset(w * 0.35, w * 0.25), Offset(w * 0.35, w * 0.39), p);

    // − (top-right)
    canvas.drawLine(Offset(w * 0.58, w * 0.32), Offset(w * 0.72, w * 0.32), p);

    // × (bottom-left)
    canvas.drawLine(Offset(w * 0.28, w * 0.61), Offset(w * 0.42, w * 0.75), p);
    canvas.drawLine(Offset(w * 0.42, w * 0.61), Offset(w * 0.28, w * 0.75), p);

    // = (bottom-right)
    canvas.drawLine(Offset(w * 0.58, w * 0.64), Offset(w * 0.72, w * 0.64), p);
    canvas.drawLine(Offset(w * 0.58, w * 0.72), Offset(w * 0.72, w * 0.72), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
