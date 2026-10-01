import 'package:get/get.dart';
import 'fees_controller.dart';
import 'pay_now_controller.dart';

class FeesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FeesController());
    Get.lazyPut(() => PayNowController());
  }
}
