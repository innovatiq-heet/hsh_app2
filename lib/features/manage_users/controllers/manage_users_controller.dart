import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/repository/staff_users/staff_users_repository.dart';
import '../../../core/network/request/staff_users/save_staff_user_request.dart';
import '../../../core/network/responses/complaints/complaint_catalog.dart';
import '../../../core/network/responses/staff_users/staff_user.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/validators.dart';

/// Admin → Manage Users: staff accounts (complain-solver, laundry-man) that
/// sign in with their mobile number alone.
class ManageUsersController extends GetxController with LoadStateMixin {
  final StaffUsersRepository _repository = Get.find();
  final ComplaintsRepository _complaints = Get.find();

  final users = <StaffUser>[].obs;

  /// Roles the server allows, for the role dropdown.
  final roles = <String>[].obs;

  /// Complaint categories a complaint solver can be limited to.
  final complaintCategories = <ComplaintCategory>[].obs;

  /// Users with a toggle/delete request in flight.
  final busyIds = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        final result = await _repository.list();
        users.assignAll(result.users);
        roles.assignAll(result.roles);
        await _loadComplaintCategories();
      }, showLoading: showLoading);

  Future<void> _loadComplaintCategories() async {
    try {
      complaintCategories.assignAll(await _complaints.categories());
    } catch (_) {
      // Without the list the form can still keep a solver on all categories.
    }
  }

  /// Creates the user. [categoryIds] applies to complaint solvers only
  /// (`null` = all categories). Returns the error to show in the form (e.g.
  /// the server's 409 "already used by …" message as-is), or `null` on success.
  Future<String?> create({
    required String name,
    required String phone,
    required String role,
    List<int>? categoryIds,
  }) async {
    final isSolver = role == StaffUser.complaintSolverRole;
    try {
      final user = await _repository.create(
        SaveStaffUserRequest(
          name: name.trim(),
          phoneNumber: Validators.normalizeMobile(phone) ?? phone.trim(),
          role: role,
          categoryIds: isSolver ? categoryIds : null,
          sendCategoryIds: isSolver,
        ),
      );
      users.insert(0, user);
      AppSnackbar.success(
        'User created',
        '${user.name} can now sign in with ${user.phoneNumber}.',
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong, try again';
    }
  }

  /// Saves only the fields that differ from [user] (the API takes a partial
  /// update). [categoryIds] (`null` = all) is sent only for a complaint
  /// solver whose categories changed; moving a solver to another role makes
  /// the API drop them. Returns the error to show, or `null` on success.
  Future<String?> edit(
    StaffUser user, {
    required String name,
    required String phone,
    required String role,
    List<int>? categoryIds,
  }) async {
    final normalizedPhone = Validators.normalizeMobile(phone) ?? phone.trim();
    final categoriesChanged = role == StaffUser.complaintSolverRole &&
        !sameCategoryIds(categoryIds, user.isComplaintSolver ? user.categoryIds : null);
    final request = SaveStaffUserRequest(
      name: name.trim() == user.name ? null : name.trim(),
      phoneNumber: normalizedPhone == user.phoneNumber ? null : normalizedPhone,
      role: role == user.role ? null : role,
      categoryIds: categoriesChanged ? categoryIds : null,
      sendCategoryIds: categoriesChanged,
    );
    if (request.isEmpty) return null;
    try {
      _replace(await _repository.update(user.id, request));
      AppSnackbar.success('User updated', 'Changes saved for ${name.trim()}.');
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong, try again';
    }
  }

  /// Turning a user off signs them out at once. Optimistic; rolled back if
  /// the request fails.
  Future<void> setActive(StaffUser user, bool isActive) async {
    if (busyIds.contains(user.id) || user.isActive == isActive) return;
    busyIds.add(user.id);
    _replace(user.copyWith(isActive: isActive));
    try {
      _replace(
        await _repository.update(user.id, SaveStaffUserRequest(isActive: isActive)),
      );
      AppSnackbar.success(
        isActive ? 'User activated' : 'User deactivated',
        isActive
            ? '${user.name} can sign in again.'
            : '${user.name} has been signed out.',
      );
    } on ApiException catch (e) {
      _replace(user);
      AppSnackbar.error('Update failed', e.message);
    } catch (_) {
      _replace(user);
      AppSnackbar.error('Update failed', 'Something went wrong, try again');
    } finally {
      busyIds.remove(user.id);
    }
  }

  Future<void> delete(StaffUser user) async {
    if (busyIds.contains(user.id)) return;
    busyIds.add(user.id);
    try {
      await _repository.delete(user.id);
      users.removeWhere((u) => u.id == user.id);
      AppSnackbar.success('User deleted', '${user.name} was removed.');
    } on ApiException catch (e) {
      AppSnackbar.error('Delete failed', e.message);
    } catch (_) {
      AppSnackbar.error('Delete failed', 'Something went wrong, try again');
    } finally {
      busyIds.remove(user.id);
    }
  }

  void _replace(StaffUser updated) {
    final index = users.indexWhere((u) => u.id == updated.id);
    if (index != -1) users[index] = updated;
  }

  /// Same selection, ignoring order; `null` (all categories) only equals `null`.
  static bool sameCategoryIds(List<int>? a, List<int>? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.toSet().length == b.toSet().length && a.toSet().containsAll(b);
  }

  static String? validateName(String? value) {
    final requiredError = Validators.required(value, message: 'Enter a name');
    if (requiredError != null) return requiredError;
    if (value!.trim().length > 100) return 'Name must be at most 100 characters';
    return null;
  }
}
