import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';

/// Read-only, tap-to-pick field for a date, time, or date+time value.
/// Replaces the date/time controllers previously duplicated ad hoc across
/// Leave, Sabha scheduling, Pay Now (cheque date) and Attendance-on-behalf.
class DateTimePickerField extends StatelessWidget {
  final String label;
  final String? displayValue;
  final VoidCallback onTap;
  final IconData icon;
  final String placeholder;

  const DateTimePickerField({
    super.key,
    required this.label,
    required this.displayValue,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
    this.placeholder = 'Select',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.gapMd),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.label),
                  Text(
                    displayValue?.isNotEmpty == true
                        ? displayValue!
                        : placeholder,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: displayValue?.isNotEmpty == true
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
