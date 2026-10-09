import 'package:get/get.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../features/phonebook/services/caller_id_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/shorebird_service.dart';
import '../../../core/storage/session_store.dart';

class SplashController extends GetxController {
  final SessionStore _sessionStore = Get.find<SessionStore>();

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Check for Shorebird OTA patches in background without blocking startup
    ShorebirdService.instance.checkForUpdatesAndDownload();

    await Future.delayed(const Duration(milliseconds: 600));
    final token = await _sessionStore.token;

    if (token == null || token.trim().isEmpty) {
      Get.offAllNamed(Routes.login);
      return;
    }

    // Configure ApiClient with the stored Bearer token
    if (Get.isRegistered<ApiClient>()) {
      Get.find<ApiClient>().setAuthToken(token);
    }

    // Sync FCM push notification token with backend now that ApiClient has the token
    if (Get.isRegistered<PushNotificationService>()) {
      PushNotificationService.to.syncTokenWithBackend();
    }

    // Resolve active session and role
    final session = await _sessionStore.userSession;
    final role = session?.role ?? await _sessionStore.role;

    // Restrict Admin access to authorized mobile numbers only
    if (role == UserRole.admin || role == UserRole.warden) {
      if (!AppConfig.isAllowedAdminPhone(session?.phone)) {
        await _sessionStore.logout();
        Get.offAllNamed(Routes.login);
        return;
      }
    }

    // Re-arm background screen-time sync on every launch for active hostel students
    final isAlumni = session?.isAlumni ?? false;
    if (role.isStudentOrLeader && !isAlumni) {
      await ScreenTimeService.startMonitoring(token);
    } else {
      await ScreenTimeService.stopMonitoring();
    }

    // Directly route to student profile / home screen (or AlumniHub for alumni)
    _routeByRole(
      role == UserRole.unknown ? UserRole.student : role,
      isAlumni: isAlumni,
    );
  }

  /// Launched by tapping a caller-ID popup: land on the phonebook with that student.
  Future<void> _openCallerIdTargetIfAny(UserRole role) async {
    final target = await CallerIdService.consumeLaunchTarget();
    if (target == null || target['target'] != 'phonebook' || !role.canOperate) return;
    // Let the role's home route settle first, then push the phonebook on top.
    await Future.delayed(const Duration(milliseconds: 400));
    Get.toNamed(Routes.operatorDirectory, arguments: {
      'studentId': target['studentId'],
      'query': target['query'],
    });
  }

  void _routeByRole(UserRole role, {bool isAlumni = false}) {
    _openCallerIdTargetIfAny(role);
    switch (role) {
      case UserRole.student:
      case UserRole.leader:
        if (isAlumni) {
          Get.offAllNamed(Routes.alumniHub);
        } else {
          Get.offAllNamed(Routes.studentHome);
        }
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
