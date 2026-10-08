import '../../features/alumni/bindings/alumni_binding.dart';
import '../../features/alumni/views/alumni_hub_screen.dart';
import '../../features/alumni/views/alumni_admin_hub_screen.dart';
import '../../features/alumni/views/alumni_directory_screen.dart';
import '../../features/alumni/views/alumni_profile_screen.dart';
import '../../features/alumni/views/alumni_profile_edit_screen.dart';
import '../../features/alumni/views/alumni_events_screen.dart';
import '../../features/alumni/views/alumni_mentorship_screen.dart';
import '../../features/alumni/views/alumni_jobs_screen.dart';
import '../../features/alumni/views/alumni_news_screen.dart';
import 'package:get/get.dart';
import '../../features/screentime/bindings/student_screen_time_binding.dart';
import '../../features/screentime/views/student_screen_time_screen.dart';
import '../../features/screentime/views/device_setup_screen.dart';
import '../../features/attendance/bindings/attendance_binding.dart';
import '../../features/attendance/views/attendance_history_screen.dart';
import '../../features/attendance/views/attendance_qr_display_screen.dart';
import '../../features/attendance/views/attendance_scanner_screen.dart';
import '../../features/chat/views/chat_screen.dart';
import '../../features/complaints/bindings/complaint_module_binding.dart';
import '../../features/complaints/views/complaint_module_screen.dart';
import '../../features/complaints/views/complaint_admin_detail_screen.dart';
import '../../features/complaints/bindings/complaint_solver_binding.dart';
import '../../features/complaints/views/add_complaint_screen.dart';
import '../../features/complaints/views/complaint_detail_screen.dart';
import '../../features/complaints/bindings/complaints_binding.dart';
import '../../features/fees/bindings/fees_binding.dart';
import '../../features/fees/views/fees_screen.dart';
import '../../features/fees/views/pay_now_screen.dart';
import '../../features/fees/views/payment_receipt_screen.dart';
import '../../features/home/bindings/home_binding.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/laundry/bindings/laundry_ticket_detail_binding.dart';
import '../../features/laundry/views/laundry_ticket_detail_screen.dart';
import '../../features/laundry/bindings/laundry_module_binding.dart';
import '../../features/laundry/views/laundry_module_screen.dart';
import '../../features/leave/views/add_leave_screen.dart';
import '../../features/leave/bindings/leave_binding.dart';
import '../../features/leave/views/leave_screen.dart';
import '../../features/auth/bindings/login_binding.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/notes/bindings/notes_binding.dart';
import '../../features/notes/views/notes_screen.dart';
import '../../features/operator/views/operator_admissions_screen.dart';
import '../../features/operator/views/operator_attendance_behalf_screen.dart';
import '../../features/operator/bindings/operator_binding.dart';
import '../../features/operator/views/operator_deposit_debit_screen.dart';
import '../../features/operator/views/operator_fee_approvals_screen.dart';
import '../../features/operator/views/operator_home_screen.dart';
import '../../features/operator/views/operator_leave_approvals_screen.dart';
import '../../features/operator/views/operator_mark_left_screen.dart';
import '../../features/operator/views/operator_room_swap_screen.dart';
import '../../features/operator/views/operator_sabha_screen.dart';
import '../../features/phonebook/bindings/phonebook_binding.dart';
import '../../features/phonebook/views/phonebook_screen.dart';
import '../../features/auth/bindings/register_binding.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/services/views/services_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/splash/bindings/splash_binding.dart';
import '../../features/splash/views/splash_screen.dart';
import '../../features/student_profile/bindings/edit_profile_binding.dart';
import '../../features/student_profile/views/edit_profile_screen.dart';
import '../../features/vehicle/views/vehicle_redirect_screen.dart';
import '../../features/geofence/bindings/admin_geofence_binding.dart';
import '../../features/geofence/views/admin_geofence_screen.dart';
import '../../features/geofence/bindings/student_locations_binding.dart';
import '../../features/geofence/views/student_locations_screen.dart';
import '../../features/shared/screens/no_internet_screen.dart';
import 'app_routes.dart';

/// The GetPage table for every route in [Routes].
///
/// Kept separate from `main.dart` so the app entry point stays a plain
/// bootstrap file. Routes are grouped by user role for readability.
class AppPages {
  AppPages._();

  static final List<GetPage> pages = [
    // â”€â”€ Auth â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    // â”€â”€ Student â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    GetPage(
      name: Routes.operatorAlumni,
      page: () => const AlumniAdminHubScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniHub,
      page: () => const AlumniHubScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniDirectory,
      page: () => const AlumniDirectoryScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniProfile,
      page: () => const AlumniProfileScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniEditProfile,
      page: () => const AlumniProfileEditScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniEvents,
      page: () => const AlumniEventsScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniMentorship,
      page: () => const AlumniMentorshipScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniJobs,
      page: () => const AlumniJobsScreen(),
      binding: AlumniBinding(),
    ),
    GetPage(
      name: Routes.alumniNews,
      page: () => const AlumniNewsScreen(),
      binding: AlumniBinding(),
    ),

    GetPage(name: Routes.setting, page: () => const SettingScreen()),
    GetPage(name: Routes.vehicle, page: () => const VehicleRedirectScreen()),
    GetPage(
      name: Routes.studentScreenTime,
      page: () => const StudentScreenTimeScreen(),
      binding: StudentScreenTimeBinding(),
    ),
    GetPage(
      name: Routes.deviceSetup,
      page: () => const DeviceSetupScreen(),
      transition: Transition.fadeIn,
    ),

    // â”€â”€ Laundry module (staff / warden / admin) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GetPage(
      name: Routes.laundryModule,
      page: () => const LaundryModuleScreen(),
      binding: LaundryModuleBinding(),
    ),

    // â”€â”€ Complaint solver module (complainsolver / admin / warden) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    // â”€â”€ Operator shell (admin / warden) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GetPage(
      name: Routes.operatorShell,
      page: () => const OperatorHomeScreen(),
      binding: OperatorBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: Routes.operatorDirectory,
      page: () => const PhonebookScreen(),
      binding: PhonebookBinding(),
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
    GetPage(
      name: Routes.operatorGeofence,
      page: () => const AdminGeofenceScreen(),
      binding: AdminGeofenceBinding(),
    ),
    GetPage(
      name: Routes.operatorStudentLocations,
      page: () => const StudentLocationsScreen(),
      binding: StudentLocationsBinding(),
    ),

    // â”€â”€ Utility â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GetPage(
      name: Routes.noInternet,
      page: () => const NoInternetScreen(showBackButton: true),
    ),
  ];
}
