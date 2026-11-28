import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/screen_time_utils.dart';
import 'student_detail_widget.dart';
import 'app_brand_icon.dart';
import 'app_install_status_pill.dart';

/// "What is this phone doing right now?" — presence, foreground app, last
/// report time, and a loud warning if the student switched monitoring off.
class LiveStatusCard extends StudentDetailWidget {
  final bool showRecentChips;
  const LiveStatusCard({
    super.key,
    required super.controller,
    this.showRecentChips = true,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isTodaySelected) return _archiveBanner();

      final online = controller.isOnline.value;
      final screenOn = controller.isScreenOn.value;
      final app = controller.currentApp.value;
      final lastApp = controller.lastUsedApp.value;
      final lastPkg = controller.lastUsedAppPackage.value;
      final lastAgo = formatLastUsedAgo(
        controller.lastUsedAppMinutesAgo.value,
        controller.lastUsedAppAt.value,
      );
      final recentApps = controller.recentApps;
      final lastSeen = controller.lastSeenAt.value;
      final comp = controller.compliance;
      final battery = controller.batteryLevel.value;
      final charging = controller.isCharging.value;
      final offlineSuspected = controller.isOfflineSuspected;

      final isActivelyUsing = screenOn && app.isNotEmpty && app != 'Idle';
      final color = online
          ? (screenOn ? AppColors.successGreen : AppColors.warningOrange)
          : AppColors.textLight;
      final title = online
          ? (screenOn ? 'Screen on' : 'Standby (screen off)')
          : 'Offline';
      final subtitle = online
          ? (isActivelyUsing ? 'Using $app' : 'Not using the phone')
          : (lastSeen != null
              ? 'Last report ${relativeTime(lastSeen)}'
              : 'No report from this phone yet');

      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulsingDot(color: color, animate: online && screenOn),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTextStyles.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (battery >= 0) ...[
                            const SizedBox(width: 8),
                            _BatteryPill(level: battery, isCharging: charging),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (screenOn && app.isNotEmpty && app != 'Idle')
                  AppBrandIcon(
                    packageName: controller.currentPackage.value,
                    appName: app,
                    size: 38,
                    showBadge: false,
                  )
                else if (online && lastSeen != null)
                  Text(
                    DateFormat('HH:mm').format(lastSeen),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // One row: HSH app installed? + Monitoring summary (tap to see each permission).
            _StatusStrip(
              installStatus: appInstallStatus(
                compliance: Map<String, dynamic>.from(comp),
                online: online,
              ),
              checks: comp.isEmpty ? const [] : monitoringChecks(Map<String, dynamic>.from(comp)),
            ),
            if (!isActivelyUsing && lastApp.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    AppBrandIcon(
                      packageName: lastPkg,
                      appName: lastApp,
                      size: 24,
                      showBadge: false,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last used app',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            lastAgo.isNotEmpty ? '$lastApp · $lastAgo' : lastApp,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showRecentChips && recentApps.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Recently used',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in recentApps.take(4))
                    _RecentAppChip(item: item),
                ],
              ),
            ],
            if (offlineSuspected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lastSeen != null
                                ? 'Device Disconnected (Offline since ${DateFormat('h:mm a').format(lastSeen)})'
                                : 'Device Disconnected (No report today)',
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The student may have turned off Wi-Fi/Mobile Data, switched on Airplane mode, or powered off the phone. Cached curfew & app limits remain active locally.',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _archiveBanner() {
    final dStr = controller.effectiveSelectedDate;
    String formatted = dStr;
    try {
      formatted = DateFormat('EEEE, d MMM yyyy').format(DateTime.parse(dStr));
    } catch (_) {}
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Viewing $formatted',
              style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => controller.selectDate(controller.todayDateStr),
            child: const Text('Back to today'),
          ),
        ],
      ),
    );
  }
}

class _RecentAppChip extends StatelessWidget {
  final Map<String, dynamic> item;
  const _RecentAppChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = (item['appName'] ?? item['app_name'] ?? item['packageName'] ?? item['package_name'] ?? '').toString().trim();
    final pkg = (item['packageName'] ?? item['package_name'] ?? '').toString().trim();
    final mins = toInt(item['minutes']);
    final minsAgoRaw = item['minutesAgo'] ?? item['minutes_ago'];
    final minsAgo = minsAgoRaw != null ? toInt(minsAgoRaw) : null;
    final ago = formatLastUsedAgo(minsAgo, null);
    final meta = [
      if (mins > 0) formatMinutes(mins),
      if (ago.isNotEmpty) ago,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBrandIcon(packageName: pkg, appName: name, size: 16, showBadge: false),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              meta.isNotEmpty ? '$name · $meta' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.animate)
              Container(
                width: 10 + 12 * _c.value,
                height: 10 + 12 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1 - _c.value) * 0.35),
                ),
              ),
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatteryPill extends StatelessWidget {
  final int level;
  final bool isCharging;
  const _BatteryPill({required this.level, required this.isCharging});

  @override
  Widget build(BuildContext context) {
    final isLow = level <= 20;
    final isModerate = level <= 35;
    final color = isLow
        ? AppColors.cancelledRed
        : (isModerate ? AppColors.warningOrange : AppColors.successGreen);

    final IconData icon;
    if (isCharging) {
      icon = Icons.battery_charging_full_rounded;
    } else if (level <= 15) {
      icon = Icons.battery_alert_rounded;
    } else if (level <= 30) {
      icon = Icons.battery_3_bar_rounded;
    } else if (level <= 60) {
      icon = Icons.battery_5_bar_rounded;
    } else {
      icon = Icons.battery_full_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            '$level%',
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// The compact status row under the live status: the HSH app install pill
/// and a Monitoring chip ("All on" / "2 off"). Tapping the chip opens the list
/// of every permission HSH needs, on or off, from the phone's last report.
class _StatusStrip extends StatefulWidget {
  final AppInstallStatus installStatus;
  final List<MonitoringCheck> checks;

  const _StatusStrip({required this.installStatus, required this.checks});

  @override
  State<_StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<_StatusStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final checks = widget.checks;
    final off = checks.where((c) => !c.on).length;
    final chipColor = off == 0 ? AppColors.successGreen : AppColors.errorRed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppInstallStatusPill(status: widget.installStatus, compact: true),
            if (checks.isNotEmpty)
              Semantics(
                button: true,
                expanded: _expanded,
                label: 'Monitoring permissions',
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: chipColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(off == 0 ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                            size: 12, color: chipColor),
                        const SizedBox(width: 3),
                        Text(
                          off == 0 ? 'Monitoring: all on' : 'Monitoring: $off off',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: chipColor),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more_rounded, size: 16, color: chipColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_expanded || checks.isEmpty
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final c in checks) _row(c)],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _row(MonitoringCheck c) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            c.on ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: c.on ? AppColors.successGreen : AppColors.errorRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.label,
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.on ? AppColors.textPrimary : AppColors.errorRed,
                  ),
                ),
                if (!c.on)
                  Text(
                    'Off: ${c.whatItDoes} not working',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            c.on ? 'On' : 'Off',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: c.on ? AppColors.successGreen : AppColors.errorRed,
            ),
          ),
        ],
      ),
    );
}
