import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../../storage/session_store.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/gradient_header.dart';
import 'attendance_event_style.dart';
import 'attendance_qr_display_controller.dart';

class AttendanceQrDisplayScreen
    extends GetView<AttendanceQrDisplayController> {
  const AttendanceQrDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isKiosk = controller.isKioskMode.value;
      final style = AttendanceEventStyle.of(controller.selectedType.value);
      final qrSize = isKiosk ? 290.0 : 250.0;

      return Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: Column(
          children: [
            if (!isKiosk)
              GradientHeader(
                overline: 'Attendance Kiosk',
                title: '${style.label} Attendance',
                subtitle: 'Live rotating QR code for student verification',
                leading: null,
                actions: [
                  HeaderIconButton(
                    icon: Icons.fullscreen_rounded,
                    tooltip: 'Fullscreen Kiosk',
                    onPressed: controller.toggleKioskMode,
                  ),
                  HeaderIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh Token',
                    onPressed: () => controller.fetchToken(),
                  ),
                  _buildMenuButton(context),
                ],
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const HeaderPill(
                        icon: Icons.timer_outlined,
                        label: 'Rotates every 20s (30s TTL)',
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      const HeaderPill(
                        icon: Icons.security_rounded,
                        label: 'Anti-Proxy Signature',
                      ),
                    ],
                  ),
                ),
              )
            else
              // Immersive Kiosk Top Header (Hero Gradient & Branding)
              _buildKioskHeader(context, style),

            // 1. Event Type Selector Bar
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.screenPadding,
                vertical: AppDimens.gapMd,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AttendanceType.values.map((type) {
                    final isSelected = controller.selectedType.value == type;
                    final evStyle = AttendanceEventStyle.of(type);

                    return Padding(
                      padding: const EdgeInsets.only(right: AppDimens.gapSm),
                      child: _chip(
                        label: '${evStyle.emoji} ${type.label}',
                        isSelected: isSelected,
                        activeColor: evStyle.primaryColor,
                        onTap: () => controller.selectEventType(type),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // 2. Main Centered QR Code and Countdown
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Session Info Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.gapLg,
                          vertical: AppDimens.gapSm,
                        ),
                        decoration: BoxDecoration(
                          color: style.softBackgroundColor,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusPill),
                          border: Border.all(
                            color: style.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              style.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: AppDimens.gapSm),
                            Text(
                              '${style.label} Attendance',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 14,
                                color: style.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: style.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Text(
                              DateFormatting.dateOnly(DateTime.now()),
                              style: AppTextStyles.caption.copyWith(
                                color: style.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimens.gapLg),

                      // QR Container Card
                      AppCard(
                        padding: EdgeInsets.all(
                          isKiosk ? AppDimens.gapXl * 1.1 : AppDimens.gapXl,
                        ),
                        radius: AppDimens.radiusXl,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (controller.isLoading.value)
                              SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            else if (controller.errorMessage.isNotEmpty)
                              SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.wifi_off_rounded,
                                        color: AppColors.cancelledRed,
                                        size: 44,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Connection Error',
                                        style: AppTextStyles.subtitle,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        controller.errorMessage.value,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(height: 16),
                                      AppButton(
                                        label: 'Retry',
                                        expand: false,
                                        onPressed: () =>
                                            controller.fetchToken(),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 380),
                                transitionBuilder: (child, animation) {
                                  final rotate = Tween<double>(
                                    begin: math.pi / 2,
                                    end: 0.0,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  );
                                  return AnimatedBuilder(
                                    animation: rotate,
                                    child: child,
                                    builder: (context, child) {
                                      return Transform(
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, 0.001)
                                          ..rotateY(rotate.value),
                                        alignment: Alignment.center,
                                        child: child,
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  key: ValueKey<String>(
                                    controller.currentToken.value,
                                  ),
                                  width: qrSize,
                                  height: qrSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusMd,
                                    ),
                                  ),
                                  child: QrImageView(
                                    data: controller.currentToken.value,
                                    version: QrVersions.auto,
                                    size: qrSize,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: AppColors.headerBlue,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape:
                                          QrDataModuleShape.square,
                                      color: AppColors.headerBlue,
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: AppDimens.gapLg),

                            // Countdown Progress Indicator
                            _RotationCountdownRing(
                              remainingSeconds:
                                  controller.remainingSeconds.value,
                              totalSeconds: 30,
                              activeColor: style.primaryColor,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimens.gapLg),

                      // Security anti-proxy footer pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusPill),
                          border: Border.all(
                            color: AppColors.successGreen.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: AppColors.successGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Anti-Proxy Active • Tokens expire after 30 seconds',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (isKiosk) ...[
                        const SizedBox(height: AppDimens.gapSm),
                        Text(
                          'Scan using your Hostel Student App to mark attendance',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }  Widget _buildKioskHeader(BuildContext context, AttendanceEventStyle style) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimens.radiusXl),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapSm,
                AppDimens.screenPadding,
                AppDimens.gapMd,
              ),
              child: Row(
                children: [
                  // Left: Event Icon Badge
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        style.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapSm),

                  // Center: Title & Live indicator (Flexible & constrained)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'KIOSK • LIVE',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${style.label} Attendance',
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapSm),

                  // Right: Exit button pill
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: const StadiumBorder(
                      side: BorderSide(color: Colors.white24),
                    ),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusPill),
                      onTap: controller.toggleKioskMode,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fullscreen_exit_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Exit',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Refresh Button
                  HeaderIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh Token',
                    onPressed: () => controller.fetchToken(),
                  ),

                  // Menu Button
                  _buildMenuButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppDimens.gapSm),
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            onSelected: (val) {
              if (val == 'history') {
                Get.toNamed(Routes.attendanceHistory);
              } else if (val == 'on_behalf') {
                Get.toNamed(Routes.operatorAttendanceOnBehalf);
              } else if (val == 'sabha') {
                Get.toNamed(Routes.operatorSabha);
              } else if (val == 'logout') {
                SessionStore.instance.clear();
                Get.offAllNamed(Routes.login);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Text('Attendance History', style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'on_behalf',
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Text('Mark on Behalf', style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sabha',
                child: Row(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Text('Sabha Attendance', style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: AppColors.cancelledRed,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Log Out',
                      style: TextStyle(
                        color: AppColors.cancelledRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final color = activeColor ?? AppColors.primary;
    return Material(
      color: isSelected ? color : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? color : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RotationCountdownRing extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final Color activeColor;

  const _RotationCountdownRing({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3.5,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  remainingSeconds <= 5
                      ? AppColors.cancelledRed
                      : activeColor,
                ),
              ),
              Center(
                child: Text(
                  '${remainingSeconds}s',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dynamic Rotating QR',
              style: AppTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Rotates automatically every 20s',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
