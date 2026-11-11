import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';

/// Admin-only screens (compose, history, detail) check the role on open, in
/// addition to the operator tile being `adminOnly`.
mixin BroadcastAdminGate on GetxController {
  /// Set when a non-admin opened the screen and was sent back.
  final accessDenied = false.obs;

  /// True for an admin. Otherwise closes the screen and returns false.
  Future<bool> ensureAdmin() async {
    final role = Get.isRegistered<SessionStore>()
        ? await Get.find<SessionStore>().role
        : UserRole.unknown;
    if (role == UserRole.admin) return true;
    accessDenied.value = true;
    // Pop the route itself: Get.back() would close a snackbar first (GetX 4).
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) nav.pop();
    AppSnackbar.error('Access Denied', 'Broadcasts can only be sent by hostel administrators.');
    return false;
  }
}
