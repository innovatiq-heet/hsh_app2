import 'package:get/get.dart';
import 'complain_home_controller.dart';
import 'complain_management_controller.dart';
import 'complain_module_controller.dart';
import 'complain_orders_controller.dart';

class ComplainModuleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainModuleController());
    Get.lazyPut(() => ComplainHomeController());
    Get.lazyPut(() => ComplainOrdersController());
    Get.lazyPut(() => ComplainManagementController());
  }
}
