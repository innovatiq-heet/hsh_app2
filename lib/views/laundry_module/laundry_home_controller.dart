import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/laundry_status.dart';
import '../../common_models/charts/chart_point.dart';
import '../../network/repository/laundry/laundry_repository.dart';

class LaundryHomeController extends GetxController with LoadStateMixin {
  final LaundryRepository _repository = Get.find();

  final statusCounts = <ChartPoint>[].obs;
  final totalTickets = 0.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    final tickets = await _repository.tickets();
    totalTickets.value = tickets.length;
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
