import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/complaint_status.dart';
import '../../common_models/charts/chart_point.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/responses/complaints/complaint_response.dart';

class ComplainHomeController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();

  final statusCounts = <ChartPoint>[].obs;
  final categoryCounts = <ChartPoint>[].obs;
  final totalComplaints = 0.obs;
  final pendingCount = 0.obs;
  final reviewedCount = 0.obs;
  final resolvedCount = 0.obs;
  final activeCount = 0.obs;
  final resolutionRate = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    final List<ComplaintResponse> list = await _repository.adminComplaints();
    totalComplaints.value = list.length;
    pendingCount.value =
        list.where((c) => c.status == ComplaintStatus.pending).length;
    reviewedCount.value =
        list.where((c) => c.status == ComplaintStatus.reviewed).length;
    resolvedCount.value =
        list.where((c) => c.status == ComplaintStatus.resolved).length;
    activeCount.value =
        list.where((c) => c.status != ComplaintStatus.resolved).length;

    if (totalComplaints.value > 0) {
      resolutionRate.value =
          (resolvedCount.value / totalComplaints.value) * 100;
    } else {
      resolutionRate.value = 0.0;
    }

    // Status breakdown chart points
    statusCounts.assignAll(
      ComplaintStatus.values.map(
        (s) => ChartPoint(
          label: s.label,
          value: list.where((c) => c.status == s).length.toDouble(),
        ),
      ),
    );

    // Category breakdown chart points
    final categories = [
      'Electrical',
      'Plumbing',
      'Furniture',
      'Housekeeping',
      'Internet/Wifi',
      'Other',
    ];

    categoryCounts.assignAll(
      categories.map(
        (cat) => ChartPoint(
          label: cat == 'Internet/Wifi' ? 'Wifi' : cat,
          value: list
              .where((c) => c.category.toLowerCase() == cat.toLowerCase())
              .length
              .toDouble(),
        ),
      ),
    );
  });
}
