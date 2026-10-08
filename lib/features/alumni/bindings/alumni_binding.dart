import 'package:get/get.dart';
import '../../../core/network/repository/alumni/alumni_repository.dart';
import '../controllers/alumni_controller.dart';

class AlumniBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AlumniRepository>()) {
      Get.lazyPut<AlumniRepository>(() => AlumniRepository());
    }
    if (!Get.isRegistered<AlumniController>()) {
      Get.lazyPut<AlumniController>(() => AlumniController());
    }
  }
}
