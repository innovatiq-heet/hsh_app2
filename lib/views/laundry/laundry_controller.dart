import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/laundry_status.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/responses/laundry/laundry_responses.dart';

class LaundryController extends GetxController with LoadStateMixin {
  final LaundryRepository _repository = Get.find();

  final balanceModel = Rxn<LaundryBalanceModel>();
  final balance = 0.0.obs;
  final totalRecharges = 0.0.obs;
  final totalSpend = 0.0.obs;

  final tickets = <LaundryTicketModel>[].obs;
  final selectedStatusFilter = Rxn<LaundryStatus>();

  List<LaundryTicketModel> get filteredTickets {
    if (selectedStatusFilter.value == null) return tickets;
    return tickets.where((t) => t.status == selectedStatusFilter.value).toList();
  }

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
    final b = results[0] as LaundryBalanceModel;
    balanceModel.value = b;
    balance.value = b.balance;
    totalRecharges.value = b.totalRecharges;
    totalSpend.value = b.totalSpend;

    tickets.assignAll(results[1] as List<LaundryTicketModel>);
  });

  void setFilter(LaundryStatus? status) {
    selectedStatusFilter.value = status;
  }
}
