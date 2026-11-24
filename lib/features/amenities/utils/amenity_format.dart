import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';

/// Labels, colours and text for Amenities. The only per-kind things in the
/// app are the fixed enums; everything else comes from the API.
class AmenityFormat {
  AmenityFormat._();

  static String status(AssetStatus s) => switch (s) {
        AssetStatus.active => 'Active',
        AssetStatus.issueReported => 'Issue reported',
        AssetStatus.inspectionRequired => 'Inspection',
        AssetStatus.underRepair => 'Under repair',
        AssetStatus.damaged => 'Damaged',
        AssetStatus.lost => 'Lost',
        AssetStatus.retired => 'Retired',
      };

  static Color statusColor(AssetStatus s) => switch (s) {
        AssetStatus.active => PhonebookTheme.green,
        AssetStatus.issueReported || AssetStatus.inspectionRequired => PhonebookTheme.amber,
        AssetStatus.underRepair => PhonebookTheme.blue,
        AssetStatus.damaged || AssetStatus.lost => PhonebookTheme.red,
        AssetStatus.retired => PhonebookTheme.muted,
      };

  static String condition(AssetCondition c) => switch (c) {
        AssetCondition.newItem => 'New',
        AssetCondition.good => 'Good',
        AssetCondition.fair => 'Fair',
        AssetCondition.poor => 'Poor',
        AssetCondition.unusable => 'Unusable',
      };

  static String placement(AssetPlacement p) => switch (p) {
        AssetPlacement.inStore => 'In store',
        AssetPlacement.withStudent => 'With a student',
        AssetPlacement.installed => 'Installed',
      };

  static String bulkState(BulkState s) => switch (s) {
        BulkState.available => 'Available',
        BulkState.assigned => 'Assigned',
        BulkState.underRepair => 'Under repair',
        BulkState.damaged => 'Damaged',
        BulkState.lost => 'Lost',
        BulkState.retired => 'Retired',
      };

  static String locationKind(LocationKind k) => switch (k) {
        LocationKind.building => 'Building',
        LocationKind.wing => 'Wing',
        LocationKind.floor => 'Floor',
        LocationKind.room => 'Room',
        LocationKind.area => 'Area',
      };

  static String warranty(String? w) => switch (w) {
        'expired' => 'Warranty expired',
        'expiring' => 'Warranty ending soon',
        'active' => 'Under warranty',
        _ => 'No warranty',
      };

  /// "₹4,500" / "₹4,500.50" from the API's decimal string; "-" when missing.
  static String money(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null) return '-';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: n == n.roundToDouble() ? 0 : 2);
    return fmt.format(n);
  }

  /// "12 Jan 2025" or "-".
  static String date(String? ymd) {
    final s = DateFormatting.calendarDate(ymd);
    return s.isEmpty ? '-' : s;
  }

  /// "1 yr 10 mo old", "8 months old".
  static String age(int? months) {
    if (months == null || months < 0) return '-';
    if (months < 12) return '$months month${months == 1 ? '' : 's'} old';
    final y = months ~/ 12, m = months % 12;
    return m == 0 ? '$y yr${y == 1 ? '' : 's'} old' : '$y yr $m mo old';
  }

  /// Colour from the API's "#RRGGBB", else [fallback].
  static Color color(String? hex, {Color fallback = PhonebookTheme.blue}) {
    final h = (hex ?? '').replaceAll('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v == null ? fallback : Color(v);
  }

  /// A small, fixed set of icon names the admin can pick for a category.
  static const icons = <String, IconData>{
    'bolt': Icons.bolt_rounded,
    'plumbing': Icons.plumbing_rounded,
    'chair': Icons.chair_rounded,
    'bed': Icons.bed_rounded,
    'key': Icons.key_rounded,
    'security': Icons.security_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'ac_unit': Icons.ac_unit_rounded,
    'water_drop': Icons.water_drop_rounded,
    'wifi': Icons.wifi_rounded,
    'fire_extinguisher': Icons.fire_extinguisher_rounded,
    'kitchen': Icons.kitchen_rounded,
    'cleaning_services': Icons.cleaning_services_rounded,
    'solar_power': Icons.solar_power_rounded,
    'inventory': Icons.inventory_2_rounded,
  };

  static IconData icon(String? name) => icons[name] ?? Icons.inventory_2_rounded;

  /// The asset code inside scanned text: "HSH-FAN-00124" from the code itself,
  /// a URL ending in it, or any text containing it. Null when there is none.
  static String? assetCodeIn(String? text) {
    final m = RegExp(r'HSH-[A-Z0-9]{2,6}-\d{5}', caseSensitive: false).firstMatch(text ?? '');
    return m?.group(0)?.toUpperCase();
  }

  /// One readable line for a lifecycle event.
  static String event(AmenityEvent e) {
    final d = e.data;
    String? s(String k) {
      final v = d[k];
      return v == null ? null : '$v';
    }

    final from = s('from_label') ?? s('from');
    final to = s('to_label') ?? s('to');
    return switch (e.event) {
      'created' => 'Added to the register',
      'purchased' => 'Purchased${s('vendor') != null ? ' from ${s('vendor')}' : ''}',
      'installed' => 'Installed${to != null ? ' at $to' : ''}',
      'assigned' => 'Given to ${to ?? 'a student'}',
      'returned' => 'Returned${from != null ? ' by $from' : ''}',
      'transferred' => 'Moved${from != null ? ' from $from' : ''}${to != null ? ' to $to' : ''}',
      'status_changed' => 'Status: ${_statusWord(from)} → ${_statusWord(to)}',
      'condition_changed' => 'Condition: ${from ?? '-'} → ${to ?? '-'}',
      'issue_reported' => 'Issue reported',
      'maintenance_started' => 'Repair started',
      'maintenance_completed' => 'Repair completed${s('cost') != null ? ' · ${money(s('cost'))}' : ''}',
      'edited' => _edited(d),
      'retired' => 'Retired',
      'found' => 'Found again',
      'stock_added' => 'Stock added${s('quantity') != null ? ' · ${s('quantity')}' : ''}',
      'stock_moved' => 'Moved ${s('quantity') ?? ''} ${from ?? ''} → ${to ?? ''}'.trim(),
      'migrated' => 'Brought over from Room Keys',
      _ => e.event.replaceAll('_', ' '),
    };
  }

  static String _statusWord(String? api) =>
      api == null ? '-' : status(AssetStatus.parse(api));

  static String _edited(Map<String, dynamic> d) {
    final changes = d['changes'];
    if (changes is Map && changes.isNotEmpty) {
      return [
        for (final e in changes.entries)
          if (e.value is List && (e.value as List).length == 2)
            '${e.key.toString().replaceAll('_', ' ')}: ${(e.value as List)[0] ?? '-'} → ${(e.value as List)[1] ?? '-'}'
          else
            e.key.toString().replaceAll('_', ' '),
      ].join(' · ');
    }
    return 'Details edited';
  }

  static IconData eventIcon(String event) => switch (event) {
        'created' || 'purchased' || 'stock_added' => Icons.add_box_outlined,
        'installed' => Icons.build_circle_outlined,
        'assigned' => Icons.person_add_alt_1_outlined,
        'returned' => Icons.keyboard_return_rounded,
        'transferred' => Icons.swap_horiz_rounded,
        'status_changed' || 'condition_changed' => Icons.sync_alt_rounded,
        'issue_reported' => Icons.report_problem_outlined,
        'maintenance_started' || 'maintenance_completed' => Icons.handyman_outlined,
        'retired' => Icons.archive_outlined,
        'found' => Icons.search_rounded,
        'migrated' => Icons.move_down_rounded,
        _ => Icons.edit_note_rounded,
      };
}

/// Small coloured label (status, condition, warranty).
class AmenityChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const AmenityChip(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
