import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/storage/session_store.dart';

/// Single source of truth for who can do what in Space & Amenities.
///
/// Every screen in this feature used to re-derive its own role checks from
/// [SessionStore] independently, which let two screens disagree on the same
/// data: a room's resident list (name, numeric id, bank code) was shown to
/// anyone while the Room Keys section right below it, in the same screen,
/// was admin/warden only. Route to every screen here before this helper
/// existed anyway: only admin and warden land on the operator home screen
/// (`LoginController._routeByRole`), but `complainsolver` can still reach
/// [AssetDetailsScreen] directly from a complaint
/// (`complaint_admin_detail_screen.dart`), so these checks are real, not
/// theoretical.
class SpaceAmenityAccess {
  SpaceAmenityAccess._();

  static UserRole get _role =>
      Get.find<SessionStore>().currentSession?.role ?? UserRole.unknown;

  /// Configure space types/categories/schedules, add/edit/archive spaces,
  /// register amenities, transfer or replace assets.
  static bool get canConfigure => _role.canOperate;

  /// Maintenance workspace, logging a maintenance action on an asset, and
  /// anything else a complaint solver is also trusted with.
  static bool get canMaintain => _role.canSolveComplaints;

  /// A room's resident list and its Room Keys — the same sensitivity, so
  /// gated the same way (admin/warden only).
  static bool get canViewResidents => _role.canOperate;

  static bool get isStudentOrLeader => _role.isStudentOrLeader;
}
