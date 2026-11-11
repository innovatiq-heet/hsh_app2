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

/// "What is this phone doing right now?" — presence, foreground app, last
/// report time, and a loud warning if the student switched monitoring off.
class LiveStatusCard extends StudentDetailWidget {
  const LiveStatusCard({super.key, required super.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isTodaySelected) return _archiveBanner();

      final online = controller.isOnline.value;
      final screenOn = controller.isScreenOn.value;
      final app = controller.currentApp.value;
      final lastSeen = controller.lastSeenAt.value;
      final tampered = controller.isTampered;
      final comp = controller.compliance;
      final battery = controller.batteryLevel.value;
      final charging = controller.isCharging.value;
      final hasInstallPass = controller.hasActiveInstallPass;
      final offlineSuspected = controller.isOfflineSuspected;

      final color = online
          ? (screenOn ? AppColors.successGreen : AppColors.warningOrange)
          : AppColors.textLight;
      final title = online
          ? (screenOn ? 'Screen on' : 'Standby (screen off)')
          : 'Offline';
      final subtitle = online
          ? (screenOn && app.isNotEmpty && app != 'Idle' ? 'Using $app' : 'Not using the phone')
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
            if (hasInstallPass) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.install_mobile_rounded, color: Color(0xFF0284C7), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Play Store unlocked (${controller.installPassRemainingMinutes}m left for install)',
                        style: AppTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: controller.revokeInstallPass,
                      child: const Text('Revoke', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
            if (offlineSuspected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                        color: AppColors.warningOrange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unreachable for >30 minutes',
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warningOrange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The phone may be turned off, in Airplane mode, or out of battery.',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (tampered) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.gpp_bad_rounded, color: AppColors.warningOrange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monitoring switched off on this phone',
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warningOrange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${[
                              if (comp['usageAccess'] == false) 'Usage access',
                              if (comp['accessibilityEnabled'] == false) 'App blocker',
                              if (comp['batteryOptimizationIgnored'] == false) 'Battery exemption',
                              if (comp['locationEnabled'] == false) 'GPS location service',
                              if (comp['locationPermission'] == 'denied' || comp['locationPermission'] == 'foreground') 'Location tracking',
                            ].join(' • ')} disabled. Usage numbers or geofence alerts below may be incomplete.',
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
