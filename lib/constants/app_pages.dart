import 'package:get/get.dart';
import '../views/attendance/attendance_binding.dart';
import '../views/attendance/attendance_history_screen.dart';
import '../views/chat/chat_screen.dart';
import '../views/complain_module/complain_module_binding.dart';
import '../views/complain_module/complain_module_screen.dart';
import '../views/complain_solver/complain_admin_detail_screen.dart';
import '../views/complain_solver/complain_solver_binding.dart';
import '../views/complaints/add_complaint_screen.dart';
import '../views/complaints/complaint_detail_screen.dart';
import '../views/complaints/complaints_binding.dart';
import '../views/fees/fees_binding.dart';
import '../views/fees/fees_screen.dart';
import '../views/fees/pay_now_screen.dart';
import '../views/fees/payment_receipt_screen.dart';
import '../views/home/home_binding.dart';
import '../views/home/home_screen.dart';
import '../views/laundry/laundry_ticket_detail_binding.dart';
import '../views/laundry/laundry_ticket_detail_screen.dart';
import '../views/laundry_module/laundry_module_binding.dart';
import '../views/laundry_module/laundry_module_screen.dart';
import '../views/leave/add_leave_screen.dart';
import '../views/leave/leave_binding.dart';
import '../views/leave/leave_screen.dart';
import '../views/login/login_binding.dart';
import '../views/login/login_screen.dart';
import '../views/notes/notes_binding.dart';
import '../views/notes/notes_screen.dart';
import '../views/operator/operator_admissions_screen.dart';
import '../views/operator/operator_attendance_behalf_screen.dart';
import '../views/operator/operator_binding.dart';
import '../views/operator/operator_deposit_debit_screen.dart';
import '../views/operator/operator_directory_screen.dart';
import '../views/operator/operator_fee_approvals_screen.dart';
import '../views/operator/operator_home_screen.dart';
import '../views/operator/operator_leave_approvals_screen.dart';
import '../views/operator/operator_mark_left_screen.dart';
import '../views/operator/operator_room_swap_screen.dart';
import '../views/operator/operator_sabha_screen.dart';
import '../views/register/register_binding.dart';
import '../views/register/register_screen.dart';
import '../views/services/services_screen.dart';
import '../views/setting/setting_screen.dart';
import '../views/splash/splash_binding.dart';
import '../views/splash/splash_screen.dart';
import '../views/student_profile/edit_profile_binding.dart';
import '../views/student_profile/edit_profile_screen.dart';
import '../views/vehicle/vehicle_redirect_screen.dart';
import 'app_routes.dart';

/// The GetPage table for every route in [Routes]. Kept separate from
/// main.dart so the app entry point stays a plain bootstrap file.
class AppPages {
  AppPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginScreen(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.register,
      page: () => const RegisterScreen(),
      binding: RegisterBinding(),
    ),

    // Student
    GetPage(
      name: Routes.studentHome,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.studentProfileEdit,
      page: () => const EditProfileScreen(),
      binding: EditProfileBinding(),
    ),
    GetPage(
      name: Routes.attendanceHistory,
      page: () => const AttendanceHistoryScreen(),
      binding: AttendanceBinding(),
    ),
    GetPage(
      name: Routes.leave,
      page: () => const LeaveScreen(),
      binding: LeaveBinding(),
    ),
    GetPage(
      name: Routes.leaveAdd,
      page: () => const AddLeaveScreen(),
      binding: LeaveBinding(),
    ),
    GetPage(
      name: Routes.fees,
      page: () => const FeesScreen(),
      binding: FeesBinding(),
    ),
    GetPage(
      name: Routes.feesPayNow,
      page: () => const PayNowScreen(),
      binding: FeesBinding(),
    ),
    GetPage(
      name: Routes.feeReceipt,
      page: () => const PaymentReceiptScreen(),
      binding: FeesBinding(),
    ),
    GetPage(
      name: Routes.laundryTicketDetail,
      page: () => const LaundryTicketDetailScreen(),
      binding: LaundryTicketDetailBinding(),
    ),
    GetPage(
      name: Routes.complaintAdd,
      page: () => const AddComplaintScreen(),
      binding: AddComplaintBinding(),
    ),
    GetPage(
      name: Routes.complaintDetail,
      page: () => const ComplaintDetailScreen(),
      binding: ComplaintDetailBinding(),
    ),
    GetPage(
      name: Routes.notes,
      page: () => const NotesScreen(),
      binding: NotesBinding(),
    ),
    GetPage(name: Routes.chat, page: () => const ChatScreen()),
    GetPage(name: Routes.services, page: () => const ServicesScreen()),
    GetPage(name: Routes.setting, page: () => const SettingScreen()),
    GetPage(name: Routes.vehicle, page: () => const VehicleRedirectScreen()),

    // Laundry module (staff/warden/admin shared)
    GetPage(
      name: Routes.laundryModule,
      page: () => const LaundryModuleScreen(),
      binding: LaundryModuleBinding(),
    ),

    // Complaint solver module (complainsolver/admin/warden shared)
    GetPage(
      name: Routes.complainSolverModule,
      page: () => const ComplainModuleScreen(),
      binding: ComplainModuleBinding(),
    ),
    GetPage(
      name: Routes.complainAdminDetail,
      page: () => const ComplainAdminDetailScreen(),
      binding: ComplainAdminDetailBinding(),
    ),

    // Operator shell (admin/warden)
    GetPage(
      name: Routes.operatorShell,
      page: () => const OperatorHomeScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorDirectory,
      page: () => const OperatorDirectoryScreen(),
    ),
    GetPage(
      name: Routes.operatorAdmissions,
      page: () => const OperatorAdmissionsScreen(),
    ),
    GetPage(
      name: Routes.operatorRoomSwap,
      page: () => const OperatorRoomSwapScreen(),
    ),
    GetPage(
      name: Routes.operatorMarkLeft,
      page: () => const OperatorMarkLeftScreen(),
    ),
    GetPage(
      name: Routes.operatorLeaveApprovals,
      page: () => const OperatorLeaveApprovalsScreen(),
    ),
    GetPage(
      name: Routes.operatorFeeApprovals,
      page: () => const OperatorFeeApprovalsScreen(),
    ),
    GetPage(
      name: Routes.operatorDepositDebit,
      page: () => const OperatorDepositDebitScreen(),
    ),
    GetPage(
      name: Routes.operatorSabha,
      page: () => const OperatorSabhaScreen(),
    ),
    GetPage(
      name: Routes.operatorAttendanceOnBehalf,
      page: () => const OperatorAttendanceBehalfScreen(),
    ),
  ];
}
