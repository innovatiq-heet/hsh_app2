import 'package:get/get.dart';
import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Eager, not lazyPut: the splash screen's build() never reads `controller`,
    // so a lazy instance would never be constructed and the bootstrap/redirect
    // in onInit() would never run.
    Get.put(SplashController());
  }
}
