import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';

/// Ticket/receipt-style card: a gradient accent strip, then two content
/// halves separated by a dashed perforation with semicircular notches.
///
/// The notches are background-coloured circles that live on the perforation
/// row and are half-clipped by the card's rounded clip, so they always line
/// up with the dashes whatever the content height.
class ReceiptCard extends StatelessWidget {
  static const double _notch = 9;

  final Widget top;
  final Widget bottom;
  final Color accent;
  final Color backgroundColor;

  const ReceiptCard({
    super.key,
    required this.top,
    required this.bottom,
    this.accent = AppColors.primaryLight,
    this.backgroundColor = AppColors.mainBackground,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusLg);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppColors.softShadow),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.indigo, accent]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.cardPadding,
                  AppDimens.gapLg,
                  AppDimens.cardPadding,
                  AppDimens.gapMd,
                ),
                child: top,
              ),
              SizedBox(
                height: _notch * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: -_notch, top: 0, child: _hole()),
                    Positioned(right: -_notch, top: 0, child: _hole()),
                    const Positioned.fill(
                      left: _notch + 8,
                      right: _notch + 8,
                      child: CustomPaint(painter: _DashPainter()),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.cardPadding,
                  AppDimens.gapSm,
                  AppDimens.cardPadding,
                  AppDimens.cardPadding,
                ),
                child: bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hole() => Container(
    width: _notch * 2,
    height: _notch * 2,
    decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 6.0;
    const gap = 5.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
