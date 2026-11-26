import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';

/// Admin-only screens (compose, history, detail) check the role on open, in
/// addition to the operator tile being `adminOnly`.
mixin BroadcastAdminGate on GetxController {
  /// Set when a non-admin/non-leader opened the screen and was sent back.
  final accessDenied = false.obs;

  /// True when the active caller is a hostel group leader (group-scoped broadcast).
  final isLeaderView = false.obs;

  /// True for an admin. Otherwise closes the screen and returns false.
  Future<bool> ensureAdmin() async {
    final role = Get.isRegistered<SessionStore>()
        ? await Get.find<SessionStore>().role
        : UserRole.unknown;
    if (role == UserRole.admin) {
      isLeaderView.value = false;
      return true;
    }
    return _denyAccess('Broadcasts can only be sent by hostel administrators.');
  }

  /// True for an admin or student group leader. Otherwise closes the screen.
  Future<bool> ensureAdminOrLeader() async {
    final role = Get.isRegistered<SessionStore>()
        ? await Get.find<SessionStore>().role
        : UserRole.unknown;
    if (role == UserRole.admin) {
      isLeaderView.value = false;
      return true;
    }
    if (role == UserRole.leader) {
      isLeaderView.value = true;
      return true;
    }
    return _denyAccess('Broadcasts are only available for hostel administrators and group leaders.');
  }

  bool _denyAccess(String message) {
    accessDenied.value = true;
    // Pop the route itself: Get.back() would close a snackbar first (GetX 4).
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) nav.pop();
    AppSnackbar.error('Access Denied', message);
    return false;
  }
}
