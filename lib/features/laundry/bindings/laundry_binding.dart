import 'package:get/get.dart';
import '../controllers/laundry_controller.dart';

class LaundryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LaundryController());
  }
}
