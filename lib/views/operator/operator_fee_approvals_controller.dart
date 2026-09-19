import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/responses/fees/fee_responses.dart';

class OperatorFeeApprovalsController extends GetxController
    with LoadStateMixin {
  final OperatorRepository _repository = Get.find();

  final transactions = <FeeTransactionResponse>[].obs;
  final decidingId = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    transactions.assignAll(await _repository.pendingTransactions());
  });

  Future<void> decide(String id, {required bool approve}) async {
    decidingId.value = id;
    try {
      await _repository.decideTransaction(id, approve: approve);
      transactions.removeWhere((t) => t.id == id);
    } finally {
      decidingId.value = null;
    }
  }
}
