import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';

class SpaceAmenityUi {
  SpaceAmenityUi._();

  static final RegExp _assetCodeRegex = RegExp(r'\bHSH-[A-Z0-9]{2,8}-\d{5}\b', caseSensitive: false);

  static String? assetCodeIn(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final m = _assetCodeRegex.firstMatch(raw.trim());
    return m?.group(0)?.toUpperCase();
  }

  static IconData iconFor(String key) {
    switch (key.toLowerCase().trim()) {
      case 'bed':
      case 'student_room':
        return Icons.bed_outlined;
      case 'menu_book':
      case 'study_room':
        return Icons.menu_book_outlined;
      case 'local_library':
      case 'library':
        return Icons.local_library_outlined;
      case 'admin_panel_settings':
      case 'rector_room':
        return Icons.admin_panel_settings_outlined;
      case 'business_center':
      case 'office':
        return Icons.business_center_outlined;
      case 'weekend':
      case 'common_space':
        return Icons.weekend_outlined;
      case 'mode_fan_off':
      case 'fan':
        return Icons.wind_power_outlined;
      case 'lightbulb':
      case 'light':
        return Icons.lightbulb_outline_rounded;
      case 'water_heater':
      case 'geyser':
        return Icons.water_damage_outlined;
      case 'toggle_on':
        return Icons.toggle_on_outlined;
      case 'ac_unit':
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'desk':
      case 'study_table':
        return Icons.desk_outlined;
      case 'door_sliding':
      case 'cupboard':
        return Icons.door_sliding_outlined;
      case 'meeting_room':
      case 'door':
        return Icons.meeting_room_outlined;
      case 'window':
        return Icons.window_outlined;
      case 'chair':
        return Icons.chair_outlined;
      case 'water_drop':
      case 'tap':
        return Icons.water_drop_outlined;
      case 'shower':
        return Icons.shower_outlined;
      case 'router':
        return Icons.router_outlined;
      case 'fire_extinguisher':
        return Icons.fire_extinguisher_outlined;
      case 'kitchen':
        return Icons.kitchen_outlined;
      case 'electrical_services':
        return Icons.electrical_services_outlined;
      case 'carpenter':
        return Icons.carpenter_outlined;
      case 'plumbing':
        return Icons.plumbing_outlined;
      case 'cleaning_services':
        return Icons.cleaning_services_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  static String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'working':
        return 'Working';
      case 'faulty':
        return 'Faulty';
      case 'under_repair':
        return 'Under Repair';
      case 'awaiting_replacement':
        return 'Awaiting Replacement';
      case 'replaced':
        return 'Replaced';
      case 'retired':
        return 'Retired';
      default:
        return status;
    }
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'working':
        return AppColors.successGreen;
      case 'faulty':
        return AppColors.errorRed;
      case 'under_repair':
        return PhonebookTheme.amber;
      case 'awaiting_replacement':
        return AppColors.warningOrange;
      case 'replaced':
      case 'retired':
      default:
        return PhonebookTheme.muted;
    }
  }

  static String conditionLabel(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
        return 'New';
      case 'good':
        return 'Good';
      case 'fair':
        return 'Fair';
      case 'poor':
        return 'Poor';
      case 'damaged':
        return 'Damaged';
      default:
        return condition;
    }
  }

  static Color conditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
      case 'good':
        return AppColors.successGreen;
      case 'fair':
        return PhonebookTheme.blue;
      case 'poor':
        return PhonebookTheme.amber;
      case 'damaged':
        return AppColors.errorRed;
      default:
        return PhonebookTheme.muted;
    }
  }
}
