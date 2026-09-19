import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/leave_status.dart';
import '../../network/repository/leave/leave_repository.dart';
import '../../network/responses/leave/leave_response.dart';

class LeaveController extends GetxController with LoadStateMixin {
  final LeaveRepository _repository = Get.find();

  final leaves = <LeaveResponse>[].obs;
  final selectedFilter = Rxn<LeaveStatus>();

  List<LeaveResponse> get filteredLeaves {
    final filter = selectedFilter.value;
    if (filter == null) return leaves;
    return leaves.where((l) => l.status == filter).toList();
  }

  void setFilter(LeaveStatus? status) {
    if (selectedFilter.value == status) {
      selectedFilter.value = null;
    } else {
      selectedFilter.value = status;
    }
  }

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
