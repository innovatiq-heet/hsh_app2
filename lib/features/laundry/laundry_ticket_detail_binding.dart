import 'package:get/get.dart';
import 'laundry_ticket_detail_controller.dart';

class LaundryTicketDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LaundryTicketDetailController());
  }
}
