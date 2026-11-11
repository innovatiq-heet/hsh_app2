import 'package:get/get.dart';
import '../controllers/form_analytics_controller.dart';
import '../controllers/form_editor_controller.dart';
import '../controllers/forms_list_controller.dart';
import '../controllers/student_forms_controller.dart';

class FormsListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FormsListController());
  }
}

class FormEditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FormEditorController());
  }
}

class FormAnalyticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FormAnalyticsController());
  }
}

class StudentFormsBinding extends Bindings {
  @override
  void dependencies() {
    // Kept for the fill screen, which reads the same list.
    Get.lazyPut(() => StudentFormsController(), fenix: true);
  }
}
