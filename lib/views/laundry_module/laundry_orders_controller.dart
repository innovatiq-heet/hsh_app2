import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/laundry_status.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/responses/laundry/laundry_responses.dart';

class LaundryOrdersController extends GetxController with LoadStateMixin {
  final LaundryRepository _repository = Get.find();

  final tickets = <LaundryTicketResponse>[].obs;
  final Rxn<LaundryStatus> statusFilter = Rxn<LaundryStatus>();
  final advancingTicketId = RxnString();

  List<LaundryTicketResponse> get filtered => statusFilter.value == null
      ? tickets
      : tickets.where((t) => t.status == statusFilter.value).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    tickets.assignAll(await _repository.tickets());
  });

  Future<void> advance(String ticketId) async {
    advancingTicketId.value = ticketId;
    try {
      final updated = await _repository.advanceStatus(ticketId);
      final index = tickets.indexWhere((t) => t.id == ticketId);
      tickets[index] = updated;
    } finally {
      advancingTicketId.value = null;
    }
  }
}
