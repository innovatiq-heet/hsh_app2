import 'package:get/get.dart';
import 'operator_admissions_controller.dart';
import 'operator_attendance_behalf_controller.dart';
import 'operator_deposit_debit_controller.dart';
import 'operator_directory_controller.dart';
import 'operator_fee_approvals_controller.dart';
import 'operator_leave_approvals_controller.dart';
import 'operator_mark_left_controller.dart';
import 'operator_room_swap_controller.dart';
import 'operator_sabha_controller.dart';

/// Every operator section's controller is lazy — not built until its
/// screen is opened — since only one section is visible at a time (unlike
/// the student home's IndexedStack tabs).
class OperatorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => OperatorDirectoryController(), fenix: true);
    Get.lazyPut(() => OperatorAdmissionsController(), fenix: true);
    Get.lazyPut(() => OperatorRoomSwapController(), fenix: true);
    Get.lazyPut(() => OperatorMarkLeftController(), fenix: true);
    Get.lazyPut(() => OperatorLeaveApprovalsController(), fenix: true);
    Get.lazyPut(() => OperatorFeeApprovalsController(), fenix: true);
    Get.lazyPut(() => OperatorDepositDebitController(), fenix: true);
    Get.lazyPut(() => OperatorSabhaController(), fenix: true);
    Get.lazyPut(() => OperatorAttendanceBehalfController(), fenix: true);
  }
}
