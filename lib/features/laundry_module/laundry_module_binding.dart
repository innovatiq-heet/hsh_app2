import 'package:get/get.dart';
import 'laundry_home_controller.dart';
import 'laundry_management_controller.dart';
import 'laundry_module_controller.dart';
import 'laundry_orders_controller.dart';

class LaundryModuleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LaundryModuleController());
    Get.lazyPut(() => LaundryHomeController());
    Get.lazyPut(() => LaundryOrdersController());
    Get.lazyPut(() => LaundryManagementController());
  }
}
