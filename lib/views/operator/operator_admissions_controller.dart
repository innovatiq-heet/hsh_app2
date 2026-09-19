import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/responses/operator/operator_responses.dart';

class OperatorAdmissionsController extends GetxController with LoadStateMixin {
  final OperatorRepository _repository = Get.find();

  final requests = <AdmissionRequest>[].obs;
  final approvingId = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    requests.assignAll(await _repository.pendingAdmissions());
  });

  Future<void> approve(String id) async {
    approvingId.value = id;
    try {
      await _repository.approveAdmission(id);
      requests.removeWhere((r) => r.id == id);
    } finally {
      approvingId.value = null;
    }
  }
}
