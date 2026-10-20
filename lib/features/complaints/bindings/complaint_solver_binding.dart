import 'package:get/get.dart';
import '../controllers/complaint_admin_detail_controller.dart';

class ComplainAdminDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplainAdminDetailController());
  }
}
