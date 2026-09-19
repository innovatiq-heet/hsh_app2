import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/api_exception.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import 'attendance_event_style.dart';

class AttendanceQrDisplayController extends GetxController {
  final AttendanceRepository _repository = Get.find();

  final selectedType = AttendanceType.dinner.obs;
  final currentToken = ''.obs;
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final remainingSeconds = 30.obs;
  final isKioskMode = false.obs;

  Timer? _rotationTimer;
  Timer? _countdownTimer;

  static const int ttlSeconds = 30;
  static const int rotationIntervalSeconds = 20;

  @override
  void onInit() {
    super.onInit();
    selectedType.value = AttendanceEventStyle.defaultEventForNow();
    fetchToken();
    _startTimers();
  }

  @override
  void onClose() {
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();
    if (isKioskMode.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.onClose();
  }

  void _startTimers() {
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();

    // 1-second countdown tick for UI progress ring
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      }
    });

    // Auto-fetch new token every 20 seconds before 30-second TTL
    _rotationTimer = Timer.periodic(
      const Duration(seconds: rotationIntervalSeconds),
      (timer) {
        fetchToken(isAutoRotation: true);
      },
    );
  }

  Future<void> fetchToken({bool isAutoRotation = false}) async {
    if (!isAutoRotation) {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final res = await _repository.generateQrToken(selectedType.value.apiValue);
      currentToken.value = res.token;
      remainingSeconds.value = ttlSeconds;
    } on ApiException catch (e) {
      developer.log('API exception generating QR: ${e.message}', name: 'AttendanceQrDisplay');
      errorMessage.value = e.message;
    } catch (e) {
      developer.log('Error generating QR: $e', name: 'AttendanceQrDisplay');
      errorMessage.value = 'Failed to generate dynamic QR token. Please retry.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectEventType(AttendanceType type) {
    if (selectedType.value == type) return;
    selectedType.value = type;
    remainingSeconds.value = ttlSeconds;
    fetchToken();
  }

  void toggleKioskMode() {
    isKioskMode.value = !isKioskMode.value;
    if (isKioskMode.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}
