import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// A small icon followed by a caption: dates, counts, audience on cards.
class MetaText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final int maxLines;

  const MetaText({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.textMuted,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
