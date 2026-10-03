import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../controllers/student_screen_time_controller.dart';
import 'app_brand_icon.dart';

/// "What is this phone doing right now?" — presence, foreground app, last
/// report time, and a loud warning if the student switched monitoring off.
class LiveStatusCard extends GetView<StudentScreenTimeController> {
  const LiveStatusCard({super.key});

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

      final color = online
          ? (screenOn ? AppColors.successGreen : AppColors.warningOrange)
          : AppColors.textLight;
      final title = online
          ? (screenOn ? 'Screen on' : 'Standby (screen off)')
          : 'Offline';
      final subtitle = online
          ? (screenOn && app.isNotEmpty && app != 'Idle' ? 'Using $app' : 'Not using the phone')
          : (lastSeen != null
              ? 'Last report ${StudentScreenTimeController.relativeTime(lastSeen)}'
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
                      Text(title, style: AppTextStyles.title),
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
                            ].join(' • ')} disabled. Usage numbers below may be incomplete.',
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
