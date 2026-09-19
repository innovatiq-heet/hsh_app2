import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Staggered entrance: fades the child in while it slides up with a slight
/// spring overshoot. [index] staggers siblings; the delay is capped so long
/// lists don't leave the bottom items waiting.
///
/// Plays once per State — rebuilding the parent (e.g. an Obx refresh) does
/// not replay it, as long as the widget keeps its position/key.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration step;
  final Duration duration;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 55),
    this.duration = const Duration(milliseconds: 560),
    this.offset = 28,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _maxStaggered = 10;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final delay = widget.step * math.min(widget.index, _maxStaggered);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _slide.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
