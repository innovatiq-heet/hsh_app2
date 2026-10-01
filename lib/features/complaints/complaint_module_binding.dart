import 'package:get/get.dart';
import 'complaint_home_controller.dart';
import 'complaint_management_controller.dart';
import 'complaint_module_controller.dart';
import 'complaint_orders_controller.dart';

class ComplainModuleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainModuleController());
    Get.lazyPut(() => ComplainHomeController());
    Get.lazyPut(() => ComplainOrdersController());
    Get.lazyPut(() => ComplainManagementController());
  }
}
