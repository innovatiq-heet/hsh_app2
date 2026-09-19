import 'package:get/get.dart';
import 'attendance_controller.dart';
import 'attendance_history_controller.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AttendanceController());
    Get.lazyPut(() => AttendanceHistoryController());
  }
}
