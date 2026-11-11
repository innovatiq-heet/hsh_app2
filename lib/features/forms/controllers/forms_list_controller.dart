import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/forms/forms_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import 'forms_manager_gate.dart';

/// Operator → Forms & Polls: every form and poll with response stats.
class FormsListController extends GetxController with LoadStateMixin, FormsManagerGate {
  FormsListController({FormsRepository? repository})
      : _repo = repository ?? Get.find<FormsRepository>();

  final FormsRepository _repo;

  final forms = <HostelForm>[].obs;

  /// `null` = all statuses.
  final filter = Rxn<FormStatus>();

  /// Forms with a toggle/delete in flight.
  final busyIds = <int>{}.obs;

  List<HostelForm> get visible =>
      filter.value == null ? forms : forms.where((f) => f.status == filter.value).toList();

  int countOf(FormStatus status) => forms.where((f) => f.status == status).length;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    if (await ensureManager()) {
      await load();
    } else {
      isLoading.value = false;
    }
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        forms.assignAll(await _repo.list());
      }, showLoading: showLoading);

  /// Pauses or activates [form]: shown at once, rolled back on failure.
  Future<void> toggle(HostelForm form) async {
    if (busyIds.contains(form.id)) return;
    final index = forms.indexWhere((f) => f.id == form.id);
    if (index == -1) return;
    busyIds.add(form.id);
    final before = forms[index];
    final pausing = before.isActive;
    forms[index] = before.copyWith(
      isActive: !pausing,
      status: pausing ? FormStatus.disabled : before.status,
    );
    try {
      final isActive = await _repo.toggle(form.id);
      final i = forms.indexWhere((f) => f.id == form.id);
      if (i != -1) forms[i] = forms[i].copyWith(isActive: isActive);
      AppSnackbar.success(isActive ? 'Activated' : 'Paused', '"${form.title}" is ${isActive ? 'open again' : 'paused'}.');
      // Upcoming/active/expired is worked out by the server.
      if (isActive) await load(showLoading: false);
    } on ApiException catch (e) {
      _restore(before);
      AppSnackbar.error('Could Not Update', e.message);
    } catch (_) {
      _restore(before);
      AppSnackbar.error('Could Not Update', 'Something went wrong, try again.');
    } finally {
      busyIds.remove(form.id);
    }
  }

  void _restore(HostelForm before) {
    final i = forms.indexWhere((f) => f.id == before.id);
    if (i != -1) forms[i] = before;
  }

  /// Deletes [form] with its views and responses.
  Future<bool> delete(HostelForm form) async {
    if (busyIds.contains(form.id)) return false;
    busyIds.add(form.id);
    try {
      await _repo.delete(form.id);
      forms.removeWhere((f) => f.id == form.id);
      AppSnackbar.success('Deleted', '"${form.title}" and its responses were removed.');
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Delete Failed', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Delete Failed', 'Something went wrong, try again.');
      return false;
    } finally {
      busyIds.remove(form.id);
    }
  }
}
