import 'package:get/get.dart';
import '../controllers/add_leave_controller.dart';
import '../controllers/leave_controller.dart';

class LeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LeaveController());
    Get.lazyPut(() => AddLeaveController());
  }
}
