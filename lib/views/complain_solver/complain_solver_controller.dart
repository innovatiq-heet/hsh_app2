import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/complaint_status.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/responses/complaints/complaint_response.dart';

class ComplainSolverController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();

  final allComplaints = <ComplaintResponse>[].obs;
  final Rxn<ComplaintStatus> statusFilter = Rxn<ComplaintStatus>();

  List<ComplaintResponse> get filtered => statusFilter.value == null
      ? allComplaints
      : allComplaints.where((c) => c.status == statusFilter.value).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    allComplaints.assignAll(await _repository.list());
  });
}
