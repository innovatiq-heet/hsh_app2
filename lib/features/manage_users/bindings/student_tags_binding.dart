import 'package:get/get.dart';
import '../controllers/student_tags_controller.dart';

class StudentTagsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => StudentTagsController());
  }
}
