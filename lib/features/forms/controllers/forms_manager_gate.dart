import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';

/// Forms & Polls management is for admins and wardens (`canOperate`; the API
/// allows operator and platform-admin tokens).
mixin FormsManagerGate on GetxController {
  /// Set when someone else opened the screen and was sent back.
  final accessDenied = false.obs;

  Future<bool> ensureManager() async {
    final role = Get.isRegistered<SessionStore>()
        ? await Get.find<SessionStore>().role
        : UserRole.unknown;
    if (role.canOperate) return true;
    accessDenied.value = true;
    // Pop the route itself: Get.back() would close a snackbar first (GetX 4).
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) nav.pop();
    AppSnackbar.error('Access Denied', 'Forms & Polls are managed by hostel administrators and wardens.');
    return false;
  }
}
