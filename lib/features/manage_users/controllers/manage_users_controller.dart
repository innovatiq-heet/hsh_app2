import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/staff_users/staff_users_repository.dart';
import '../../../core/network/request/staff_users/save_staff_user_request.dart';
import '../../../core/network/responses/staff_users/staff_user.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/validators.dart';

/// Admin → Manage Users: staff accounts (complain-solver, laundry-man) that
/// sign in with their mobile number alone.
class ManageUsersController extends GetxController with LoadStateMixin {
  final StaffUsersRepository _repository = Get.find();

  final users = <StaffUser>[].obs;

  /// Roles the server allows, for the role dropdown.
  final roles = <String>[].obs;

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
      }, showLoading: showLoading);

  /// Creates the user. Returns the error to show in the form (e.g. the
  /// server's 409 "already used by …" message as-is), or `null` on success.
  Future<String?> create({
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      final user = await _repository.create(
        SaveStaffUserRequest(
          name: name.trim(),
          phoneNumber: Validators.normalizeMobile(phone) ?? phone.trim(),
          role: role,
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
  /// update). Returns the error to show, or `null` on success.
  Future<String?> edit(
    StaffUser user, {
    required String name,
    required String phone,
    required String role,
  }) async {
    final normalizedPhone = Validators.normalizeMobile(phone) ?? phone.trim();
    final request = SaveStaffUserRequest(
      name: name.trim() == user.name ? null : name.trim(),
      phoneNumber: normalizedPhone == user.phoneNumber ? null : normalizedPhone,
      role: role == user.role ? null : role,
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

  static String? validateName(String? value) {
    final requiredError = Validators.required(value, message: 'Enter a name');
    if (requiredError != null) return requiredError;
    if (value!.trim().length > 100) return 'Name must be at most 100 characters';
    return null;
  }
}
