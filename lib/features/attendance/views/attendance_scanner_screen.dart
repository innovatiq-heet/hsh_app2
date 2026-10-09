import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/enums/attendance_type.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/namedrop_attendance_overlay.dart';
import 'attendance_event_style.dart';
import '../controllers/attendance_scanner_controller.dart';

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
                            child: InkWell(
                              onTap: () => controller.setEventType(type),
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? AppColors.buttonGradient
                                      : null,
                                  color: isSelected
                                      ? null
                                      : Colors.black.withValues(alpha: 0.50),
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusPill,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.22),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.40,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      style.emoji,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      type.label,
                                      style: AppTextStyles.label.copyWith(
                                        color: Colors.white,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

          // 4. BLE Search Ripple Animation Overlay (Center of Viewfinder)
          Obx(() {
            if (!controller.isBleSearching.value) return const SizedBox.shrink();
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulsingBleRipple(),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Searching for Floor ESP-32 Beacon...',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // 5. Timeout Banner (Suggest Scan QR Instead)
          Obx(() {
            if (!controller.bleTimedOut.value || controller.isSuccessMarked.value) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: MediaQuery.of(context).padding.top + 105,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Beacon not detected. Align QR code inside the frame or move closer.',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // 6. Bottom Guidance Card
          Positioned(
            bottom: AppDimens.gapXxl,
            left: AppDimens.screenPadding,
            right: AppDimens.screenPadding,
            child: SafeArea(
              top: false,
              child: Obx(() {
                final style = AttendanceEventStyle.of(controller.selectedType.value);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(AppDimens.cardPadding),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
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
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: style.primaryColor.withValues(alpha: 0.20),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  style.icon,
                                  color: style.primaryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: AppDimens.gapSm),
                              Text(
                                'Marking ${style.emoji} ${style.label}',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.gapSm),
                          Text(
                            'Align the dynamic QR code on screen or stay near your floor beacon',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySm.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapSm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: style.primaryColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                              border: Border.all(
                                color: style.primaryColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              style.timingHint,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                color: style.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 7. Wrong Floor Detected Error Modal
          Obx(() {
            if (!controller.wrongFloorDetected.value) return const SizedBox.shrink();
            return Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                    border: Border.all(color: AppColors.cancelledRed, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cancelledRed.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.cancelledRed.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wrong_location_rounded,
                          color: AppColors.cancelledRed,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Wrong Floor Detected',
                        style: AppTextStyles.headline.copyWith(
                          color: AppColors.cancelledRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Detected Beacon: ${controller.detectedBeaconFloor.value}\nYour Assigned Floor: ${controller.assignedStudentFloor.value}\n\nPlease proceed to ${controller.assignedStudentFloor.value} to mark your attendance.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Get.back(),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cancelledRed,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: controller.retryFloorScan,
                              child: const Text('Retry Scan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // 8. Verifying State Loading Overlay
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
                        'Verifying Attendance...',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppDimens.gapXs),
                      Text(
                        'Validating beacon proximity & token signature',
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

          // 9. Celebratory Success NameDrop Overlay
          Obx(() {
            final record = controller.successRecord.value;
            if (record == null) return const SizedBox.shrink();
            final style = AttendanceEventStyle.of(record.type);

            return NamedropAttendanceOverlay(
              title: 'Attendance Marked!',
              sessionName: record.type.label,
              eventType: record.type,
              eventStyle: style,
              subtitle: 'Your attendance has been recorded successfully.',
              onDismiss: () {
                Get.back();
              },
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
      color: active ? AppColors.primary : Colors.black.withValues(alpha: 0.45),
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

    // 2. Corner Brackets in vibrant Terracotta brand color
    final cornerPaint = Paint()
      ..color = AppColors.primary
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
          AppColors.primary.withValues(alpha: 0.0),
          AppColors.primaryLight,
          AppColors.primary.withValues(alpha: 0.0),
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

class _PulsingBleRipple extends StatefulWidget {
  const _PulsingBleRipple();

  @override
  State<_PulsingBleRipple> createState() => _PulsingBleRippleState();
}

class _PulsingBleRippleState extends State<_PulsingBleRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        final t = _rippleController.value;
        final size = 68.0 + (50.0 * t);
        final opacity = (1.0 - t).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft.withValues(alpha: opacity * 0.35),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: opacity * 0.75),
                  width: 1.8,
                ),
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bluetooth_searching_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        );
      },
    );
  }
}

