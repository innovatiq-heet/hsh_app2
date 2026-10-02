import 'package:get/get.dart';
import '../controllers/phonebook_controller.dart';

class PhonebookBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PhonebookController>(() => PhonebookController());
  }
}
