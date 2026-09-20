import 'package:get/get.dart';
import 'attendance_controller.dart';
import 'attendance_history_controller.dart';
import 'attendance_qr_display_controller.dart';
import 'attendance_scanner_controller.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AttendanceController());
    Get.lazyPut(() => AttendanceHistoryController());
  }
}

class AttendanceScannerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AttendanceScannerController());
  }
}

class AttendanceQrDisplayBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AttendanceQrDisplayController());
  }
}
