import 'package:flutter/material.dart';

/// Staggered waterfall entrance animation for list items and grids.
///
/// Smoothly slides each item up and fades it in with an organic cascade delay
/// based on its [index].
class StaggeredSlideFade extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delayPerItem;
  final Duration duration;
  final double slideOffset;
  final Curve curve;

  const StaggeredSlideFade({
    super.key,
    required this.index,
    required this.child,
    this.delayPerItem = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 360),
    this.slideOffset = 18.0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<StaggeredSlideFade> createState() => _StaggeredSlideFadeState();
}

class _StaggeredSlideFadeState extends State<StaggeredSlideFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Cap the maximum stagger delay so long lists still animate promptly
    final delayMs =
        (widget.index * widget.delayPerItem.inMilliseconds).clamp(0, 360);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
