import 'package:flutter/material.dart';

/// Pinned navy header for the Screen Time sub-screens (usage, apps, ...): the
/// same gradient and arcs as the Phonebook and Screen Time headers, a round
/// back button, and a title with a subtitle that collapses into the bar.
class ScreenTimeSubHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const ScreenTimeSubHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SubHeaderDelegate(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        topPadding: MediaQuery.of(context).padding.top,
      ),
    );
  }
}

class _SubHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final double topPadding;

  _SubHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + 60.0;

  // top bar (52) + gap + title (~29) + subtitle (~17) + bottom (20)
  @override
  double get maxExtent => topPadding + 52 + 6 + 29 + 3 + 17 + 20;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular((28.0 * (1.0 - progress)).clamp(0.0, 28.0));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF03192E),
            Color(0xFF032B4F),
            Color(0xFF025A8D),
            Color(0xFF0369A1),
          ],
          stops: [0.0, 0.38, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        boxShadow: progress > 0.25
            ? [
                BoxShadow(
                  color: const Color(0xFF03192E).withValues(alpha: 0.22 * progress),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: _ArcsPainter())),
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (expandedOpacity > 0.05)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SubHeaderDelegate old) =>
      old.title != title || old.subtitle != subtitle || old.topPadding != topPadding;
}

class _ArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final c = Offset(size.width * 0.88, size.height * 0.08);
    canvas.drawCircle(c, size.width * 0.38, paint);
    canvas.drawCircle(c, size.width * 0.62, paint);
    canvas.drawCircle(c, size.width * 0.86, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
