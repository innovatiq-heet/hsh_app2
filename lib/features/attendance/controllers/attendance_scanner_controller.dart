import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/enums/attendance_type.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/attendance/attendance_repository.dart';
import '../../../core/network/request/attendance/mark_attendance_request.dart';
import '../../../core/network/responses/attendance/attendance_models.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import 'attendance_controller.dart';
import '../views/attendance_event_style.dart';

class AttendanceScannerController extends GetxController {
  final AttendanceRepository _repository = Get.find();

  static const String esp32ServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  late final MobileScannerController scannerController;

  final selectedType = AttendanceType.dinner.obs;
  final isTorchOn = false.obs;
  final isVerifying = false.obs;
  final statusMessage = ''.obs;
  final lastScannedToken = ''.obs;
  final successRecord = Rxn<AttendanceRecord>();

  // BLE Verification UI Mapping
  final isBleSearching = true.obs;
  final bleTimedOut = false.obs;
  final wrongFloorDetected = false.obs;
  final detectedBeaconFloor = ''.obs;
  final assignedStudentFloor = 'Floor 1'.obs;
  final isSuccessMarked = false.obs;

  StreamSubscription<List<ScanResult>>? _bleScanSubscription;
  Timer? _bleTimeoutTimer;
  bool _isProcessing = false;

  @override
  void onInit() {
    super.onInit();
    // Pre-select if passed as route argument, else default intelligently based on current device time
    if (Get.arguments is AttendanceType) {
      selectedType.value = Get.arguments as AttendanceType;
    } else {
      selectedType.value = AttendanceEventStyle.defaultEventForNow();
    }

    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _initAssignedFloorAndStartBle();
  }

  Future<void> _initAssignedFloorAndStartBle() async {
    try {
      final room = await Get.find<SessionStore>().cachedRoom;
      if (room != null && room.isNotEmpty) {
        final digits = room.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          final floorNum = digits.length >= 3 ? digits[0] : digits;
          assignedStudentFloor.value = 'Floor $floorNum';
        }
      }
    } catch (_) {}

    _startBleBeaconSearch();
  }

  void _startBleBeaconSearch() async {
    isBleSearching.value = true;
    bleTimedOut.value = false;
    wrongFloorDetected.value = false;

    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        isBleSearching.value = false;
        bleTimedOut.value = true;
        return;
      }

      final normalizedTargetUuid = esp32ServiceUuid.replaceAll('-', '').toLowerCase();

      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (_isProcessing || isVerifying.value || successRecord.value != null) return;

        for (final r in results) {
          final advData = r.advertisementData;
          final advName = (r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : advData.advName)
              .toLowerCase();

          bool uuidMatches = advData.serviceUuids.any(
            (u) => u.toString().replaceAll('-', '').toLowerCase() == normalizedTargetUuid,
          );
          bool nameMatches = advName.contains('esp32') ||
              advName.contains('floor') ||
              advName.contains('hostel') ||
              advName.contains('attendance') ||
              advName.contains('beacon');

          if (uuidMatches || nameMatches) {
            _onBleBeaconFound(advName, r.rssi);
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _bleTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (isBleSearching.value && successRecord.value == null && !wrongFloorDetected.value) {
          isBleSearching.value = false;
          bleTimedOut.value = true;
        }
      });
    } catch (_) {
      isBleSearching.value = false;
      bleTimedOut.value = true;
    }
  }

  Future<void> _onBleBeaconFound(String advName, int rssi) async {
    _stopBleScanning();

    // Check for Global Beacon Exception ("GLOBAL_ALL_FLOORS")
    final isGlobalBeacon = advName.contains('global') ||
        advName.contains('all_floors') ||
        advName.contains('universal') ||
        advName.contains('gate');

    // Extract floor from beacon name (e.g. "floor 2", "flr_2", "floor2")
    String beaconFloor = 'Floor 1';
    final match = RegExp(r'floor[_\s-]?(\d+)').firstMatch(advName);
    if (match != null && match.group(1) != null) {
      beaconFloor = 'Floor ${match.group(1)}';
    }

    detectedBeaconFloor.value = beaconFloor;

    // Check Floor Mismatch
    if (!isGlobalBeacon && beaconFloor.toLowerCase() != assignedStudentFloor.value.toLowerCase()) {
      wrongFloorDetected.value = true;
      isBleSearching.value = false;
      HapticFeedback.heavyImpact();
      return;
    }

    // Floor matches or Global Beacon -> Verify Attendance
    _isProcessing = true;
    isVerifying.value = true;
    isBleSearching.value = false;

    try {
      final record = await _repository.mark(
        MarkAttendanceRequest(
          type: selectedType.value,
          viaCode: false,
          rssi: rssi,
        ),
      );

      HapticFeedback.heavyImpact();
      isSuccessMarked.value = true;
      successRecord.value = record;

      Get.rawSnackbar(
        messageText: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: AppDimens.iconSm),
            const SizedBox(width: AppDimens.gapSm),
            Expanded(
              child: Text(
                'Attendance Marked successfully.',
                style: AppTextStyles.bodySm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.successGreen,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(AppDimens.gapLg),
        borderRadius: AppDimens.radiusMd,
      );

      if (Get.isRegistered<AttendanceController>()) {
        Get.find<AttendanceController>().onAttendanceMarked(record);
        Get.find<AttendanceController>().load();
      }
    } catch (e) {
      _handleScanError(e.toString(), '');
    } finally {
      isVerifying.value = false;
    }
  }

  void retryFloorScan() {
    wrongFloorDetected.value = false;
    _startBleBeaconSearch();
  }

  void _stopBleScanning() {
    _bleTimeoutTimer?.cancel();
    _bleScanSubscription?.cancel();
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  @override
  void onClose() {
    _stopBleScanning();
    scannerController.dispose();
    super.onClose();
  }

  void toggleTorch() async {
    await scannerController.toggleTorch();
    isTorchOn.value = !isTorchOn.value;
  }

  void switchCamera() async {
    await scannerController.switchCamera();
  }

  void setEventType(AttendanceType type) {
    selectedType.value = type;
  }

  void onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing || isVerifying.value) return;
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final token = rawValue.trim();
    if (token == lastScannedToken.value && !isVerifying.value) {
      return;
    }

    _processScannedToken(token);
  }

  Future<void> _processScannedToken(String qrToken) async {
    _isProcessing = true;
    isVerifying.value = true;
    lastScannedToken.value = qrToken;

    // Haptic feedback on capture
    HapticFeedback.mediumImpact();

    try {
      int? floorId;
      String? serviceUuid;
      if (Get.isRegistered<AttendanceController>()) {
        final attCtrl = Get.find<AttendanceController>();
        floorId = attCtrl.assignedFloorId.value;
        serviceUuid = attCtrl.currentFloorServiceUuid.value;
      }

      final record = await _repository.mark(
        MarkAttendanceRequest(
          type: selectedType.value,
          sessionKey: selectedType.value.apiValue,
          viaCode: true,
          qrToken: qrToken,
          floorId: floorId,
          serviceUuid: serviceUuid,
        ),
      );

      HapticFeedback.heavyImpact();
      successRecord.value = record;

      // Update student dashboard if registered
      if (Get.isRegistered<AttendanceController>()) {
        Get.find<AttendanceController>().onAttendanceMarked(record);
        Get.find<AttendanceController>().load();
      }
    } on ApiException catch (e) {
      developer.log('API Exception on scan: ${e.message}', name: 'AttendanceScanner');
      _handleScanError(e.message, qrToken);
    } catch (e) {
      developer.log('Generic error on scan: $e', name: 'AttendanceScanner');
      _handleScanError('Failed to verify attendance. Please try again.', qrToken);
    } finally {
      isVerifying.value = false;
    }
  }

  void _handleScanError(String message, String qrToken) {
    final lowerMsg = message.toLowerCase();

    // 1. Token Expired Handling
    if (lowerMsg.contains('expired')) {
      statusMessage.value = 'QR Code has expired. Please scan the current code on screen.';
      Get.rawSnackbar(
        messageText: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: Colors.white, size: AppDimens.iconSm),
            const SizedBox(width: AppDimens.gapSm),
            Expanded(
              child: Text(
                'QR Code expired! Please scan the latest code.',
                style: AppTextStyles.bodySm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cancelledRed,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(AppDimens.gapLg),
        borderRadius: AppDimens.radiusMd,
      );
      // Auto-resume scanner after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        _isProcessing = false;
      });
      return;
    }

    // 2. Type Mismatch Handling (e.g., scanned Lunch during Dinner)
    for (final t in AttendanceType.values) {
      if (lowerMsg.contains('is for "${t.apiValue}"') ||
          lowerMsg.contains('for "${t.label.toLowerCase()}"') ||
          lowerMsg.contains('is for ${t.apiValue}')) {
        _promptTypeMismatch(detectedType: t, originalToken: qrToken);
        return;
      }
    }

    // 3. Other errors (duplicate, unauthorized, network)
    statusMessage.value = message;
    Get.rawSnackbar(
      message: message,
      backgroundColor: AppColors.cancelledRed,
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(AppDimens.gapLg),
      borderRadius: AppDimens.radiusMd,
    );

    Future.delayed(const Duration(seconds: 3), () {
      _isProcessing = false;
    });
  }

  void _promptTypeMismatch({
    required AttendanceType detectedType,
    required String originalToken,
  }) {
    final detectedStyle = AttendanceEventStyle.of(detectedType);
    final selectedStyle = AttendanceEventStyle.of(selectedType.value);

    Get.defaultDialog(
      title: 'Event Mismatch',
      titleStyle: AppTextStyles.title,
      middleText:
          'This QR code is for ${detectedStyle.emoji} ${detectedStyle.label}, but you currently have ${selectedStyle.emoji} ${selectedStyle.label} selected.\n\nWould you like to switch to ${detectedStyle.label} and mark attendance?',
      middleTextStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      radius: AppDimens.radiusXl,
      textConfirm: 'Switch & Mark ${detectedStyle.label}',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: detectedStyle.primaryColor,
      onConfirm: () {
        Get.back();
        selectedType.value = detectedType;
        _isProcessing = false;
        _processScannedToken(originalToken);
      },
      onCancel: () {
        _isProcessing = false;
      },
    );
  }

  void resumeScanning() {
    successRecord.value = null;
    statusMessage.value = '';
    _isProcessing = false;
  }
}
