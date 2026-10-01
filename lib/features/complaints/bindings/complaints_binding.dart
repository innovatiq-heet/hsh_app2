import 'package:get/get.dart';
import '../controllers/add_complaint_controller.dart';
import '../controllers/complaint_detail_controller.dart';
import '../controllers/complaints_controller.dart';

class ComplaintsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplaintsController());
  }
}

class AddComplaintBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AddComplaintController());
  }
}

class ComplaintDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ComplaintDetailController());
  }
}
