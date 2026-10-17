import 'package:get/get.dart';
import '../controllers/admin_birthday_controller.dart';

class AdminBirthdayBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminBirthdayController>(() => AdminBirthdayController());
  }
}
