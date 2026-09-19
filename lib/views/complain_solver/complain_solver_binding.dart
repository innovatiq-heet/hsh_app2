import 'package:get/get.dart';
import 'complain_admin_detail_controller.dart';
import 'complain_solver_controller.dart';

class ComplainSolverBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainSolverController());
  }
}

class ComplainAdminDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainAdminDetailController());
  }
}
