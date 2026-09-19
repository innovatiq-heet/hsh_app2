import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/laundry/submit_laundry_request.dart';
import '../../network/responses/laundry/laundry_responses.dart';

class LaundryController extends GetxController with LoadStateMixin {
  final LaundryRepository _repository = Get.find();

  final balance = 0.0.obs;
  final tickets = <LaundryTicketResponse>[].obs;
  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    final results = await Future.wait([
      _repository.balance(),
      _repository.tickets(),
    ]);
    balance.value = (results[0] as LaundryBalanceResponse).balance;
    tickets.assignAll(results[1] as List<LaundryTicketResponse>);
  });

  Future<void> submit(int itemCount, String note) async {
    isSubmitting.value = true;
    try {
      await _repository.submit(
        SubmitLaundryRequest(itemCount: itemCount, note: note),
      );
      await load();
    } finally {
      isSubmitting.value = false;
    }
  }
}
