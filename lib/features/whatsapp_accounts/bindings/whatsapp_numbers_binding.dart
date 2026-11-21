import 'package:get/get.dart';
import '../controllers/whatsapp_numbers_controller.dart';

class WhatsAppNumbersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WhatsAppNumbersController>(() => WhatsAppNumbersController());
  }
}
