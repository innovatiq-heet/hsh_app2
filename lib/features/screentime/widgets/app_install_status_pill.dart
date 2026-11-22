import 'package:flutter/material.dart';
import '../controllers/screen_time_utils.dart';

/// Installed / uninstalled status of one student's HSH app ([appInstallStatus]).
class AppInstallStatusPill extends StatelessWidget {
  final AppInstallStatus status;

  /// Shorter label for the student list.
  final bool compact;

  const AppInstallStatusPill({super.key, required this.status, this.compact = false});

  static ({String label, String short, IconData icon, Color color}) styleOf(AppInstallStatus status) =>
      switch (status) {
        AppInstallStatus.installed => (
            label: 'HSH app installed',
            short: 'Installed',
            icon: Icons.verified_rounded,
            color: const Color(0xFF16A34A),
          ),
        AppInstallStatus.protectionOff => (
            label: 'HSH app installed · protection turned off',
            short: 'Protection off',
            icon: Icons.gpp_maybe_rounded,
            color: const Color(0xFFD97706),
          ),
        AppInstallStatus.uninstalled => (
            label: 'HSH app uninstalled (protection turned off)',
            short: 'Uninstalled',
            icon: Icons.gpp_bad_rounded,
            color: const Color(0xFFDC2626),
          ),
        AppInstallStatus.notInstalled => (
            label: 'HSH app not installed / not set up',
            short: 'Not installed',
            icon: Icons.mobile_off_rounded,
            color: const Color(0xFF64748B),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = styleOf(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 5),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: s.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 12 : 15, color: s.color),
          SizedBox(width: compact ? 3 : 6),
          Flexible(
            child: Text(
              compact ? s.short : s.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w700,
                color: s.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
