import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Icon + accent color for a complaint category. Categories come from the
/// API as free strings, so unknown values fall back to a neutral style.
class ComplaintCategoryStyle {
  final IconData icon;
  final Color color;

  const ComplaintCategoryStyle(this.icon, this.color);

  static ComplaintCategoryStyle of(String category) {
    final key = category.toLowerCase();
    if (key.contains('electric')) {
      return const ComplaintCategoryStyle(
        Icons.bolt_rounded,
        AppColors.warningOrange,
      );
    }
    if (key.contains('plumb') || key.contains('water')) {
      return const ComplaintCategoryStyle(
        Icons.water_drop_outlined,
        AppColors.secondary,
      );
    }
    if (key.contains('furniture')) {
      return const ComplaintCategoryStyle(
        Icons.chair_outlined,
        Color(0xFF8B5CF6),
      );
    }
    if (key.contains('house') || key.contains('clean')) {
      return const ComplaintCategoryStyle(
        Icons.cleaning_services_outlined,
        AppColors.successGreen,
      );
    }
    if (key.contains('internet') || key.contains('wifi')) {
      return const ComplaintCategoryStyle(
        Icons.wifi_rounded,
        AppColors.primaryLight,
      );
    }
    return const ComplaintCategoryStyle(
      Icons.report_outlined,
      AppColors.textSecondary,
    );
  }
}
