import 'package:get/get.dart';
import '../controllers/screen_time_directory_controller.dart';

class StudentScreenTimeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ScreenTimeDirectoryController>(() => ScreenTimeDirectoryController());
  }
}
