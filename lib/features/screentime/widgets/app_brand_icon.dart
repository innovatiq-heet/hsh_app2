import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/app_icon_cache.dart';

class _AppStyle {
  final List<Color> gradientColors;
  final IconData? icon;
  final Color iconColor;

  const _AppStyle({
    required this.gradientColors,
    this.icon,
    this.iconColor = Colors.white,
  });
}

/// App icon for parental-control and screen-time lists.
///
/// Shows the app's real launcher icon when the student's device has uploaded
/// it (see [AppIconCache]); otherwise falls back to a recognisable brand-styled
/// placeholder so the list never shows a blank tile.
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
    // Rebuild when a real icon for this package arrives after first paint.
    return ValueListenableBuilder<int>(
      valueListenable: AppIconCache.revision,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.26);
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
                errorBuilder: (_, _, _) => _placeholder(borderRadius),
              ),
            )
          else
            _placeholder(borderRadius),

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
                      color: Colors.black.withValues(alpha: 0.2),
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

  /// Brand-coloured tile with a glyph or initial, used until the real icon is known.
  Widget _placeholder(BorderRadius borderRadius) {
    final style = _resolveAppStyle(packageName, appName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: (style.gradientColors.first).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: style.icon != null
            ? Icon(
                style.icon,
                size: size * 0.52,
                color: style.iconColor,
              )
            : Text(
                _getFallbackLetter(appName, packageName),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
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

  static _AppStyle _resolveAppStyle(String rawPkg, String rawName) {
    final pkg = rawPkg.toLowerCase().trim();
    final name = rawName.toLowerCase().trim();

    // 1. YouTube
    if (pkg.contains('youtube') || name.contains('youtube')) {
      return const _AppStyle(
        gradientColors: [Color(0xFFFF0000), Color(0xFFCC0000)],
        icon: Icons.play_arrow_rounded,
      );
    }

    // 2. Instagram
    if (pkg.contains('instagram') || name.contains('instagram')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
        icon: Icons.camera_alt_rounded,
      );
    }

    // 3. Snapchat
    if (pkg.contains('snapchat') || name.contains('snapchat')) {
      return const _AppStyle(
        gradientColors: [Color(0xFFFFFC00), Color(0xFFFFE600)],
        icon: Icons.chat_bubble_rounded,
        iconColor: Colors.black87,
      );
    }

    // 4. WhatsApp
    if (pkg.contains('whatsapp') || name.contains('whatsapp')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF25D366), Color(0xFF128C7E)],
        icon: Icons.chat_rounded,
      );
    }

    // 5. Facebook & Messenger
    if (pkg.contains('facebook') || name.contains('facebook') || pkg.contains('katana')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF1877F2), Color(0xFF0C63D4)],
        icon: Icons.facebook,
      );
    }
    if (pkg.contains('orca') || name.contains('messenger')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF00B2FF), Color(0xFF006AFF)],
        icon: Icons.bolt_rounded,
      );
    }

    // 6. Free Fire
    if (pkg.contains('freefire') || name.contains('free fire')) {
      return const _AppStyle(
        gradientColors: [Color(0xFFFF512F), Color(0xFFDD2476)],
        icon: Icons.local_fire_department_rounded,
      );
    }

    // 7. BGMI / PUBG
    if (pkg.contains('pubg') || name.contains('bgmi') || name.contains('pubg')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF2C3E50), Color(0xFFE67E22)],
        icon: Icons.gps_fixed_rounded,
      );
    }

    // 8. TikTok
    if (pkg.contains('musically') || name.contains('tiktok')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF010101), Color(0xFF222222)],
        icon: Icons.music_note_rounded,
        iconColor: Color(0xFF00F2FE),
      );
    }

    // 9. Netflix
    if (pkg.contains('netflix') || name.contains('netflix')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF141414), Color(0xFF000000)],
        icon: Icons.movie_creation_rounded,
        iconColor: Color(0xFFE50914),
      );
    }

    // 10. Spotify
    if (pkg.contains('spotify') || name.contains('spotify')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF1DB954), Color(0xFF128C43)],
        icon: Icons.headphones_rounded,
      );
    }

    // 11. Discord
    if (pkg.contains('discord') || name.contains('discord')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF5865F2), Color(0xFF4752C4)],
        icon: Icons.forum_rounded,
      );
    }

    // 12. Telegram
    if (pkg.contains('telegram') || name.contains('telegram')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF24A1DE), Color(0xFF0088CC)],
        icon: Icons.send_rounded,
      );
    }

    // 13. Twitter / X
    if (pkg.contains('twitter') || name == 'x' || name.contains('twitter')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF111111), Color(0xFF000000)],
        icon: Icons.tag_rounded,
      );
    }

    // 14. Reddit
    if (pkg.contains('reddit') || name.contains('reddit')) {
      return const _AppStyle(
        gradientColors: [Color(0xFFFF4500), Color(0xFFFF5722)],
        icon: Icons.smart_toy_rounded,
      );
    }

    // 15. Pinterest
    if (pkg.contains('pinterest') || name.contains('pinterest')) {
      return const _AppStyle(
        gradientColors: [Color(0xFFE60023), Color(0xFFB70817)],
        icon: Icons.push_pin_rounded,
      );
    }

    // 16. Chrome & Browsers
    if (pkg.contains('chrome') || name.contains('chrome')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF4285F4), Color(0xFF0F9D58)],
        icon: Icons.public_rounded,
      );
    }

    // 17. Twitch
    if (pkg.contains('twitch') || name.contains('twitch')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF9146FF), Color(0xFF6441A5)],
        icon: Icons.live_tv_rounded,
      );
    }

    // 18. Roblox / Minecraft / Gaming keywords
    if (pkg.contains('roblox') ||
        pkg.contains('mojang') ||
        pkg.contains('supercell') ||
        name.contains('game') ||
        pkg.contains('game') ||
        name.contains('clash') ||
        name.contains('craft') ||
        name.contains('cod') ||
        name.contains('asphalt')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
        icon: Icons.sports_esports_rounded,
      );
    }

    // 19. Social / Chat keywords
    if (name.contains('chat') || name.contains('social') || name.contains('message')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
        icon: Icons.chat_bubble_outline_rounded,
      );
    }

    // 20. Video / Streaming keywords
    if (name.contains('video') || name.contains('movie') || name.contains('stream') || name.contains('tv')) {
      return const _AppStyle(
        gradientColors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        icon: Icons.smart_display_rounded,
      );
    }

    // 21. Music keywords
    if (name.contains('music') || name.contains('audio') || name.contains('radio')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        icon: Icons.music_note_rounded,
      );
    }

    // 22. Shopping keywords
    if (name.contains('amazon') || name.contains('flipkart') || name.contains('shop') || name.contains('store')) {
      return const _AppStyle(
        gradientColors: [Color(0xFFF39C12), Color(0xFFD35400)],
        icon: Icons.shopping_bag_outlined,
      );
    }

    // 23. Education / Tools
    if (name.contains('study') || name.contains('book') || name.contains('class') || name.contains('learn')) {
      return const _AppStyle(
        gradientColors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
        icon: Icons.menu_book_rounded,
      );
    }

    // Deterministic pleasant gradient based on hash of package name
    final hash = (pkg.isNotEmpty ? pkg : name).hashCode.abs();
    final palettes = [
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)], // Indigo-Violet
      [const Color(0xFF2563EB), const Color(0xFF38BDF8)], // Blue-Sky
      [const Color(0xFF059669), const Color(0xFF10B981)], // Emerald
      [const Color(0xFFD97706), const Color(0xFFF59E0B)], // Amber
      [const Color(0xFFDC2626), const Color(0xFFEF4444)], // Rose
      [const Color(0xFF7C3AED), const Color(0xFFC084FC)], // Purple
      [const Color(0xFF0891B2), const Color(0xFF06B6D4)], // Cyan
      [const Color(0xFFEA580C), const Color(0xFFFB923C)], // Orange
    ];
    final selectedPalette = palettes[hash % palettes.length];

    return _AppStyle(
      gradientColors: selectedPalette,
      icon: null, // Displays bold initial letter
    );
  }
}
