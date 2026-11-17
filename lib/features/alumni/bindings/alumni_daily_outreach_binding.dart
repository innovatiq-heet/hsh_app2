import 'package:get/get.dart';
import '../../../core/network/repository/alumni/alumni_repository.dart';
import '../controllers/alumni_daily_outreach_controller.dart';

class AlumniDailyOutreachBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AlumniRepository>()) {
      Get.lazyPut<AlumniRepository>(() => AlumniRepository());
    }
    Get.lazyPut<AlumniDailyOutreachController>(() => AlumniDailyOutreachController());
  }
}
