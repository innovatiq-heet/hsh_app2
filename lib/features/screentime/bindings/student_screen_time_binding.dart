import 'package:get/get.dart';
import '../controllers/student_screen_time_controller.dart';

class StudentScreenTimeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StudentScreenTimeController>(() => StudentScreenTimeController());
  }
}
