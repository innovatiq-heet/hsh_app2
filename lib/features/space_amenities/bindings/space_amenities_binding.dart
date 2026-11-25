import 'package:get/get.dart';
import '../controllers/space_amenities_controller.dart';

class SpaceAmenitiesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SpaceAmenitiesHomeController());
  }
}
