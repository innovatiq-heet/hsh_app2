import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A smooth, high-fidelity rolling number animation for balances, counts, and currency.
///
/// Uses [TweenAnimationBuilder] under the hood so no manual [AnimationController]
/// lifecycle management is needed. Fluidly animates whenever [value] updates.
class AnimatedCounter extends StatelessWidget {
  final num value;
  final String prefix;
  final String suffix;
  final int decimals;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat(
      decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0',
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, currentValue, child) {
        final formatted = formatter.format(currentValue);
        return Text(
          '$prefix$formatted$suffix',
          style: style,
        );
      },
    );
  }
}
