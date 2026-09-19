import 'package:flutter/material.dart';

/// Counts up to [value] on first build, then animates smoothly between
/// subsequent values. [format] turns the in-flight double into display text
/// (e.g. currency, "3/5", percentages).
class AnimatedCounter extends StatelessWidget {
  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
  });

  AnimatedCounter.integer({
    super.key,
    required int value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    String suffix = '',
  }) : value = value.toDouble(),
       format = ((v) => '${v.round()}$suffix');

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}
