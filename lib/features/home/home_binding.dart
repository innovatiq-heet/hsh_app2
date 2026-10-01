import 'package:get/get.dart';
import '../attendance/attendance_binding.dart';
import '../complaints/complaints_binding.dart';
import '../laundry/laundry_binding.dart';
import '../student_profile/student_profile_binding.dart';
import 'home_controller.dart';

/// Puts the home shell's own controller plus every tab's controller, since
/// the tabs are an IndexedStack (all alive at once) rather than separate
/// routes.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HomeController());
    StudentProfileBinding().dependencies();
    ComplaintsBinding().dependencies();
    LaundryBinding().dependencies();
    AttendanceBinding().dependencies();
  }
}
