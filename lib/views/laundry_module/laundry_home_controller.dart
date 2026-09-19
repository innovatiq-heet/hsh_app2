import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/laundry_status.dart';
import '../../common_models/charts/chart_point.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/responses/laundry/laundry_responses.dart';

class LaundryHomeController extends GetxController with LoadStateMixin {
  final LaundryRepository _repository = Get.find();

  final statusCounts = <ChartPoint>[].obs;
  final totalTickets = 0.obs;
  final pendingCount = 0.obs;
  final acceptedCount = 0.obs;
  final washedCount = 0.obs;
  final receivedCount = 0.obs;
  final totalGarments = 0.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    final List<LaundryTicketModel> tickets = await _repository.adminTickets();
    totalTickets.value = tickets.length;
    pendingCount.value =
        tickets.where((t) => t.status == LaundryStatus.pending).length;
    acceptedCount.value =
        tickets.where((t) => t.status == LaundryStatus.accepted).length;
    washedCount.value =
        tickets.where((t) => t.status == LaundryStatus.washed).length;
    receivedCount.value =
        tickets.where((t) => t.status == LaundryStatus.received).length;
    totalGarments.value =
        tickets.fold(0, (sum, t) => sum + t.totalItems);

    statusCounts.assignAll(
      LaundryStatus.values.map(
        (s) => ChartPoint(
          label: s.label,
          value: tickets.where((t) => t.status == s).length.toDouble(),
        ),
      ),
    );
  });
}
