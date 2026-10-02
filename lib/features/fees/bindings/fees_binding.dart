import 'package:get/get.dart';
import '../controllers/fees_controller.dart';
import '../controllers/pay_now_controller.dart';

class FeesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FeesController());
    Get.lazyPut(() => PayNowController());
  }
}
