import 'package:get/get.dart';
import '../controllers/student_locations_controller.dart';

class StudentLocationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => StudentLocationsController());
  }
}
