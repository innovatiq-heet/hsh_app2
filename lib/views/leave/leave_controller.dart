import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/leave_status.dart';
import '../../network/repository/leave/leave_repository.dart';
import '../../network/responses/leave/leave_response.dart';

class LeaveController extends GetxController with LoadStateMixin {
  final LeaveRepository _repository = Get.find();

  final leaves = <LeaveResponse>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    leaves.assignAll(await _repository.history());
  });

  Future<void> cancel(String id) async {
    await _repository.cancel(id);
    await load();
  }

  bool canCancel(LeaveResponse leave) => leave.status == LeaveStatus.pending;
}
