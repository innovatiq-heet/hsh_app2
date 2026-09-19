import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/status_badge.dart';
import 'attendance_event_style.dart';
import 'attendance_scanner_controller.dart';

class AttendanceScannerScreen extends GetView<AttendanceScannerController> {
  const AttendanceScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mobile Camera Viewfinder
          MobileScanner(
            controller: controller.scannerController,
            onDetect: controller.onBarcodeDetected,
          ),

          // 2. Custom Dark Overlay Cutout with Laser Animation
          const _ScannerOverlay(),

          // 3. Top Controls Bar (Back, Torch, Camera Flip)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.screenPadding,
                vertical: AppDimens.gapSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Get.back(),
                        tooltip: 'Back',
                      ),
                      const Spacer(),
                      Obx(
                        () => _CircleIconButton(
                          icon: controller.isTorchOn.value
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          active: controller.isTorchOn.value,
                          onPressed: controller.toggleTorch,
                          tooltip: 'Flashlight',
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      _CircleIconButton(
                        icon: Icons.cameraswitch_rounded,
                        onPressed: controller.switchCamera,
                        tooltip: 'Switch Camera',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapMd),

                  // Event Type Selector Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Obx(
                      () => Row(
                        children: AttendanceType.values.map((type) {
                          final isSelected = controller.selectedType.value == type;
                          final style = AttendanceEventStyle.of(type);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Text(style.emoji, style: const TextStyle(fontSize: 14)),
                              label: Text(type.label),
                              selected: isSelected,
                              selectedColor: style.primaryColor,
                              shape: const StadiumBorder(),
                              labelStyle: AppTextStyles.label.copyWith(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: Colors.black54,
                              onSelected: (_) => controller.setEventType(type),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Guidance Card
          Positioned(
            bottom: AppDimens.gapXxl,
            left: AppDimens.screenPadding,
            right: AppDimens.screenPadding,
            child: SafeArea(
              top: false,
              child: Obx(() {
                final style = AttendanceEventStyle.of(controller.selectedType.value);
                return Container(
                  padding: const EdgeInsets.all(AppDimens.cardPadding),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(style.icon, color: style.primaryColor, size: 20),
                          const SizedBox(width: AppDimens.gapSm),
                          Text(
                            'Marking ${style.emoji} ${style.label}',
                            style: AppTextStyles.subtitle.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapXs),
                      Text(
                        'Align the dynamic QR code displayed on the hostel kiosk/screen inside the frame.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapXs),
                      Text(
                        style.timingHint,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: style.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          // 5. Verifying State Loading Overlay
          Obx(() {
            if (!controller.isVerifying.value) return const SizedBox.shrink();
            return Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppDimens.gapXxl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: AppDimens.gapLg),
                      Text(
                        'Verifying QR Token...',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppDimens.gapXs),
                      Text(
                        'Validating dynamic timestamp & anti-proxy signature',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // 6. Celebratory Success Sheet Overlay
          Obx(() {
            final record = controller.successRecord.value;
            if (record == null) return const SizedBox.shrink();
            final style = AttendanceEventStyle.of(record.type);

            return Container(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.gapXxl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: AppDimens.bottomNavHeight,
                          height: AppDimens.bottomNavHeight,
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.successGreen,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        Text(
                          'Attendance Marked!',
                          style: AppTextStyles.headline.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapXs),
                        Text(
                          'Your attendance for ${style.emoji} ${record.type.label} was recorded.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.gapLg,
                            vertical: AppDimens.gapMd,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Session:', style: AppTextStyles.bodySm),
                                  Text(
                                    '${style.emoji} ${record.type.label}',
                                    style: AppTextStyles.subtitle,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimens.gapXs),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Timestamp:', style: AppTextStyles.bodySm),
                                  Text(
                                    DateFormatting.dateTime(record.time),
                                    style: AppTextStyles.bodySm.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimens.gapXs),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Verification:', style: AppTextStyles.bodySm),
                                  StatusBadge(
                                    label: 'Verified QR',
                                    color: AppColors.successGreen,
                                    icon: Icons.qr_code_2_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapXl),
                        AppButton(
                          label: 'Done',
                          onPressed: () {
                            Get.back();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.secondary : Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _ScannerOverlay extends StatefulWidget {
  const _ScannerOverlay();

  @override
  State<_ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<_ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const scanAreaSize = 260.0;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ScannerPainter(
            scanAreaSize: scanAreaSize,
            animationValue: _animController.value,
          ),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double scanAreaSize;
  final double animationValue;

  _ScannerPainter({
    required this.scanAreaSize,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 30);
    final rect = Rect.fromCenter(
      center: center,
      width: scanAreaSize,
      height: scanAreaSize,
    );

    // 1. Semi-transparent backdrop
    final backgroundPaint = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, backgroundPaint);

    // 2. Corner Brackets
    final cornerPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;

    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top + cornerLength), Offset(rect.left, rect.top + 16), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.left, rect.top, 32, 32), 3.1415, 1.5707, false, cornerPaint);
    canvas.drawLine(Offset(rect.left + 16, rect.top), Offset(rect.left + cornerLength, rect.top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.top), Offset(rect.right - 16, rect.top), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.right - 32, rect.top, 32, 32), 4.7123, 1.5707, false, cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top + 16), Offset(rect.right, rect.top + cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLength), Offset(rect.left, rect.bottom - 16), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.left, rect.bottom - 32, 32, 32), 1.5707, 1.5707, false, cornerPaint);
    canvas.drawLine(Offset(rect.left + 16, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.bottom), Offset(rect.right - 16, rect.bottom), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.right - 32, rect.bottom - 32, 32, 32), 0, 1.5707, false, cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom + 16), Offset(rect.right, rect.bottom - cornerLength), cornerPaint);

    // 3. Laser Scanning Line
    final laserY = rect.top + 10 + (rect.height - 20) * animationValue;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.0),
          AppColors.secondary,
          AppColors.secondary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(rect.left, laserY - 1.5, rect.width, 3))
      ..strokeWidth = 3.0;

    canvas.drawLine(Offset(rect.left + 12, laserY), Offset(rect.right - 12, laserY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
