import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';

/// A student's own complaint (read-only; the student cannot change status).
class ComplaintDetailController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();
  late final String complaintId = '${Get.arguments ?? ''}';

  final complaint = Rxn<ComplaintResponse>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        complaint.value = await _repository.detail(complaintId);
      }, showLoading: showLoading);
}
