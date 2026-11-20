import 'package:get/get.dart';
import '../controllers/admin_anniversary_controller.dart';

class AdminAnniversaryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminAnniversaryController>(() => AdminAnniversaryController());
  }
}
