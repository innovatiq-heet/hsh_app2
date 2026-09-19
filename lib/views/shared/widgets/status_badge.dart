import 'package:flutter/material.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';

/// Generic status pill. Pass any enum's `.label`/`.color` extension values
/// (LeaveStatus, ComplaintStatus, LaundryStatus, TransactionStatus,
/// AdmissionStatus, ...) — one widget for every status vocabulary.
///
/// [pulse] marks an in-flight state (pending, under review, ...): the dot
/// emits a soft repeating ripple so open items stand out from settled ones.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool pulse;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: color)
          else if (pulse)
            PulsingDot(color: color)
          else
            _Dot(color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Status dot with an expanding, fading ripple ring.
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 6});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 2.6;
    return SizedBox.square(
      dimension: widget.size,
      child: OverflowBox(
        maxWidth: box,
        maxHeight: box,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_controller.value);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: widget.size + (box - widget.size) * t,
                    height: widget.size + (box - widget.size) * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                    ),
                  ),
                  _Dot(color: widget.color),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
