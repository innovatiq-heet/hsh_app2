import 'package:get/get.dart';
import '../controllers/laundry_ticket_detail_controller.dart';

class LaundryTicketDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LaundryTicketDetailController());
  }
}
