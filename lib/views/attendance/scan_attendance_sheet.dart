import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_routes.dart';
import 'attendance_scanner_controller.dart';

/// Opens the dynamic rotating QR scanner screen with the specified [type] pre-selected.
void showScanAttendanceSheet(BuildContext context, AttendanceType type) {
  if (Get.isRegistered<AttendanceScannerController>()) {
    Get.find<AttendanceScannerController>().setEventType(type);
  }
  Get.toNamed(Routes.attendanceScanner);
}
