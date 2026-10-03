import 'package:get/get.dart';
import '../controllers/admin_geofence_controller.dart';

class AdminGeofenceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AdminGeofenceController(), fenix: true);
  }
}
