import 'package:get/get.dart';
import '../../features/screentime/student_screen_time_binding.dart';
import '../../features/screentime/student_screen_time_screen.dart';
import '../../features/attendance/attendance_binding.dart';
import '../../features/attendance/attendance_history_screen.dart';
import '../../features/attendance/attendance_qr_display_screen.dart';
import '../../features/attendance/attendance_scanner_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/complaints/complaint_module_binding.dart';
import '../../features/complaints/complaint_module_screen.dart';
import '../../features/complaints/complaint_admin_detail_screen.dart';
import '../../features/complaints/complaint_solver_binding.dart';
import '../../features/complaints/add_complaint_screen.dart';
import '../../features/complaints/complaint_detail_screen.dart';
import '../../features/complaints/complaints_binding.dart';
import '../../features/fees/fees_binding.dart';
import '../../features/fees/fees_screen.dart';
import '../../features/fees/pay_now_screen.dart';
import '../../features/fees/payment_receipt_screen.dart';
import '../../features/home/home_binding.dart';
import '../../features/home/home_screen.dart';
import '../../features/laundry/laundry_ticket_detail_binding.dart';
import '../../features/laundry/laundry_ticket_detail_screen.dart';
import '../../features/laundry/laundry_module_binding.dart';
import '../../features/laundry/laundry_module_screen.dart';
import '../../features/leave/add_leave_screen.dart';
import '../../features/leave/leave_binding.dart';
import '../../features/leave/leave_screen.dart';
import '../../features/auth/login/login_binding.dart';
import '../../features/auth/login/login_screen.dart';
import '../../features/notes/notes_binding.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/operator/operator_admissions_screen.dart';
import '../../features/operator/operator_attendance_behalf_screen.dart';
import '../../features/operator/operator_binding.dart';
import '../../features/operator/operator_deposit_debit_screen.dart';
import '../../features/operator/operator_directory_screen.dart';
import '../../features/operator/operator_fee_approvals_screen.dart';
import '../../features/operator/operator_home_screen.dart';
import '../../features/operator/operator_leave_approvals_screen.dart';
import '../../features/operator/operator_mark_left_screen.dart';
import '../../features/operator/operator_room_swap_screen.dart';
import '../../features/operator/operator_sabha_screen.dart';
import '../../features/auth/register/register_binding.dart';
import '../../features/auth/register/register_screen.dart';
import '../../features/services/services_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_binding.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/student_profile/edit_profile_binding.dart';
import '../../features/student_profile/edit_profile_screen.dart';
import '../../features/vehicle/vehicle_redirect_screen.dart';
import '../../features/shared/screens/no_internet_screen.dart';
import 'app_routes.dart';

/// The GetPage table for every route in [Routes].
///
/// Kept separate from `main.dart` so the app entry point stays a plain
/// bootstrap file. Routes are grouped by user role for readability.
class AppPages {
  AppPages._();

  static final List<GetPage> pages = [
    // ── Auth ─────────────────────────────────────────────────────────────────
    GetPage(
      name: Routes.splash,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 380),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginScreen(),
      binding: LoginBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: Routes.register,
      page: () => const RegisterScreen(),
      binding: RegisterBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 280),
    ),

    // ── Student ───────────────────────────────────────────────────────────────
    GetPage(
      name: Routes.studentHome,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 350),
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
      name: Routes.attendanceScanner,
      page: () => const AttendanceScannerScreen(),
      binding: AttendanceScannerBinding(),
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
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 320),
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
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 320),
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
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 320),
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
    GetPage(
      name: Routes.studentScreenTime,
      page: () => const StudentScreenTimeScreen(),
      binding: StudentScreenTimeBinding(),
    ),

    // ── Laundry module (staff / warden / admin) ───────────────────────────────
    GetPage(
      name: Routes.laundryModule,
      page: () => const LaundryModuleScreen(),
      binding: LaundryModuleBinding(),
    ),

    // ── Complaint solver module (complainsolver / admin / warden) ─────────────
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

    // ── Operator shell (admin / warden) ───────────────────────────────────────
    GetPage(
      name: Routes.operatorShell,
      page: () => const OperatorHomeScreen(),
      binding: OperatorBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: Routes.operatorDirectory,
      page: () => const OperatorDirectoryScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorAdmissions,
      page: () => const OperatorAdmissionsScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorRoomSwap,
      page: () => const OperatorRoomSwapScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorMarkLeft,
      page: () => const OperatorMarkLeftScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorLeaveApprovals,
      page: () => const OperatorLeaveApprovalsScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorFeeApprovals,
      page: () => const OperatorFeeApprovalsScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorDepositDebit,
      page: () => const OperatorDepositDebitScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorSabha,
      page: () => const OperatorSabhaScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorAttendanceOnBehalf,
      page: () => const OperatorAttendanceBehalfScreen(),
      binding: OperatorBinding(),
    ),
    GetPage(
      name: Routes.operatorAttendanceQrDisplay,
      page: () => const AttendanceQrDisplayScreen(),
      binding: AttendanceQrDisplayBinding(),
    ),

    // ── Utility ───────────────────────────────────────────────────────────────
    GetPage(
      name: Routes.noInternet,
      page: () => const NoInternetScreen(showBackButton: true),
    ),
  ];
}
