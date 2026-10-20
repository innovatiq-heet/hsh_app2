import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/utils/app_snackbar.dart';

/// Solver view of one complaint: details, student and status change.
class ComplainAdminDetailController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();
  late final String complaintId = '${Get.arguments ?? ''}';

  final complaint = Rxn<ComplaintResponse>();
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        complaint.value = await _repository.detail(complaintId);
      }, showLoading: showLoading);

  Future<void> setStatus(ComplaintStatus status) async {
    if (complaint.value?.status == status || isSaving.value) return;
    isSaving.value = true;
    try {
      complaint.value = await _repository.updateStatus(complaintId, status);
      AppSnackbar.success('Status updated', 'Moved to ${status.staffLabel}.');
    } on ApiException catch (e) {
      AppSnackbar.error('Update failed', e.message);
    } catch (_) {
      AppSnackbar.error('Update failed', 'Something went wrong, try again');
    } finally {
      isSaving.value = false;
    }
  }
}
