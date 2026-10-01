import 'package:get/get.dart';
import 'student_screen_time_controller.dart';

class StudentScreenTimeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StudentScreenTimeController>(() => StudentScreenTimeController());
  }
}
