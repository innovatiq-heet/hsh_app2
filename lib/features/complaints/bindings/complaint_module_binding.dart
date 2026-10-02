import 'package:get/get.dart';
import '../controllers/complaint_home_controller.dart';
import '../controllers/complaint_management_controller.dart';
import '../controllers/complaint_module_controller.dart';
import '../controllers/complaint_orders_controller.dart';

class ComplainModuleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainModuleController());
    Get.lazyPut(() => ComplainHomeController());
    Get.lazyPut(() => ComplainOrdersController());
    Get.lazyPut(() => ComplainManagementController());
  }
}
