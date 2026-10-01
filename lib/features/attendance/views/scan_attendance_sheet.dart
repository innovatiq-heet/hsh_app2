import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/attendance_type.dart';
import '../../../core/constants/app_routes.dart';
import '../controllers/attendance_scanner_controller.dart';

/// Opens the dynamic rotating QR scanner screen with the specified [type] pre-selected.
void showScanAttendanceSheet(BuildContext context, AttendanceType type) {
  if (Get.isRegistered<AttendanceScannerController>()) {
    Get.find<AttendanceScannerController>().setEventType(type);
  }
  Get.toNamed(Routes.attendanceScanner);
}
