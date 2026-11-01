import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Colours shared by the usage charts, so the same thing is the same colour
/// everywhere: day time is the app's blue, night time the amber accent, and
/// anything over the daily limit red.
class UsageColors {
  UsageColors._();

  static const Color day = AppColors.primary;
  static const Color night = AppColors.secondaryDark;
  static const Color over = AppColors.cancelledRed;

  static Color category(String name) => switch (name) {
        'Social Media' => const Color(0xFF0284C7),
        'Entertainment' => const Color(0xFF9333EA),
        'Gaming' => const Color(0xFFEA580C),
        'Study & Tools' => const Color(0xFF16A34A),
        _ => const Color(0xFF94A3B8),
      };
}

/// Card title with a one-line explanation, used by every usage card.
class UsageCardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const UsageCardHeader({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A coloured dot with a label, for chart legends.
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
