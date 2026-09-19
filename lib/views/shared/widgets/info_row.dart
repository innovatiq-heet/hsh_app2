import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';

/// Label/value row used in detail cards. [locked] marks a field the
/// current user cannot edit (e.g. the student self-edit blocklist).
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool locked;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppDimens.gapMd),
          Text(label, style: AppTextStyles.bodySm),
          const SizedBox(width: AppDimens.gapLg),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value.isEmpty ? '—' : value,
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
