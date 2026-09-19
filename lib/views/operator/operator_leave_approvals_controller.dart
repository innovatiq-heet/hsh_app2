import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/responses/leave/leave_response.dart';

class OperatorLeaveApprovalsController extends GetxController
    with LoadStateMixin {
  final OperatorRepository _repository = Get.find();

  final leaves = <LeaveResponse>[].obs;
  final decidingId = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    leaves.assignAll(await _repository.pendingLeaves());
  });

  Future<void> decide(String id, {required bool approve}) async {
    decidingId.value = id;
    try {
      await _repository.decideLeave(id, approve: approve);
      leaves.removeWhere((l) => l.id == id);
    } finally {
      decidingId.value = null;
    }
  }
}
