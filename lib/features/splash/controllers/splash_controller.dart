import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/storage/session_store.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final sessionStore = Get.find<SessionStore>();
    final token = await sessionStore.token;

    if (token == null || token.trim().isEmpty) {
      Get.offAllNamed(Routes.login);
      return;
    }

    // Configure ApiClient with the stored Bearer token
    if (Get.isRegistered<ApiClient>()) {
      Get.find<ApiClient>().setAuthToken(token);
    }

    // Resolve active session and role
    final session = await sessionStore.userSession;
    final role = session?.role ?? await sessionStore.role;

    // Re-arm background screen-time sync on every launch for students
    if (role.isStudentOrLeader) {
      await ScreenTimeService.startMonitoring(token);
    }

    // Directly route to student profile / home screen
    _routeByRole(role == UserRole.unknown ? UserRole.student : role);
  }

  void _routeByRole(UserRole role) {
    switch (role) {
      case UserRole.student:
      case UserRole.leader:
        Get.offAllNamed(Routes.studentHome);
        break;
      case UserRole.admin:
      case UserRole.warden:
        Get.offAllNamed(Routes.operatorShell);
        break;
      case UserRole.laundry:
      case UserRole.staff:
        Get.offAllNamed(Routes.laundryModule);
        break;
      case UserRole.complainsolver:
        Get.offAllNamed(Routes.complainSolverModule);
        break;
      case UserRole.attendance:
        Get.offAllNamed(Routes.operatorAttendanceQrDisplay);
        break;
      case UserRole.unknown:
        // Defensive fallback for a role the client doesn't recognize yet.
        Get.offAllNamed(Routes.login);
        break;
    }
  }
}
