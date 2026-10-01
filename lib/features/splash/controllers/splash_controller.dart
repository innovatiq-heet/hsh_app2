import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/repository/authentication/auth_repository.dart';
import '../../../core/storage/session_store.dart';

class SplashController extends GetxController {
  final AuthRepository _authRepository = Get.find();

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final hasSession = await Get.find<SessionStore>().hasSession;
    if (!hasSession) {
      Get.offAllNamed(Routes.login);
      return;
    }

    final token = await Get.find<SessionStore>().token;
    if (token == null || token.isEmpty) {
      await Get.find<SessionStore>().clear();
      Get.offAllNamed(Routes.login);
      return;
    }

    Get.find<ApiClient>().setAuthToken(token);
    final session = await _authRepository.checkSession(token);
    if (session == null) {
      await Get.find<SessionStore>().clear();
      if (Get.currentRoute != Routes.login) {
        Get.offAllNamed(Routes.login);
      }
      return;
    }

    _routeByRole(session.role);
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
