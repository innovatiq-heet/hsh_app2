import 'package:get/get.dart';
import 'notes_controller.dart';

class NotesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NotesController());
  }
}
