import 'package:get/get.dart';

import '../controllers/amenities_home_controller.dart';

/// Amenities home (Dashboard, Inventory, Locations). The other amenity
/// screens are pushed directly and create their own repository.
class AmenitiesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AmenitiesHomeController());
  }
}
