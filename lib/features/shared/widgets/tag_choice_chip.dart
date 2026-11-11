import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/tags/student_tag_model.dart';

/// A selectable student tag in the tag's own colour.
///
/// Not a [FilterChip]: the theme gives selected chips white text on the
/// primary colour, which is unreadable on a pale tag tint.
class TagChoiceChip extends StatelessWidget {
  final StudentTag tag;
  final bool selected;
  final VoidCallback onTap;

  /// Shows "· N" after the name when true.
  final bool showCount;

  const TagChoiceChip({
    super.key,
    required this.tag,
    required this.selected,
    required this.onTap,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = tag.color;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? color : AppColors.border, width: selected ? 1.4 : 1),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle,
                  size: selected ? 16 : 10,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  tag.name,
                  style: AppTextStyles.label.copyWith(
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (showCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· ${tag.studentCount}',
                    style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
