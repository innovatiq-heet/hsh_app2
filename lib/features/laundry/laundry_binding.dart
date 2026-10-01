import 'package:get/get.dart';
import 'laundry_controller.dart';

class LaundryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LaundryController());
  }
}
