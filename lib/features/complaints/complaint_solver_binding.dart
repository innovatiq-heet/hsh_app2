import 'package:get/get.dart';
import 'complaint_module_binding.dart';
import 'complaint_admin_detail_controller.dart';
import 'complaint_solver_controller.dart';

class ComplainSolverBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainSolverController());
    ComplainModuleBinding().dependencies();
  }
}

class ComplainAdminDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainAdminDetailController());
  }
}
