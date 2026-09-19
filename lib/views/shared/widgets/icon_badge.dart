import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Rounded, tinted icon container used as the leading visual on cards,
/// tiles and list rows.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool solid;

  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 44,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: solid ? Colors.white : color, size: size * 0.5),
    );
  }
}
