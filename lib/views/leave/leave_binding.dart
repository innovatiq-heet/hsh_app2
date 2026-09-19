import 'package:get/get.dart';
import 'add_leave_controller.dart';
import 'leave_controller.dart';

class LeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LeaveController());
    Get.lazyPut(() => AddLeaveController());
  }
}
