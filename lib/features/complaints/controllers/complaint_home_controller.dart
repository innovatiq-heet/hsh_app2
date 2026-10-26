import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/models/charts/chart_point.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/responses/complaints/complaint_catalog.dart';

/// Complaints overview. The API has no count endpoint and returns at most
/// 200 complaints per request, so the figures cover the latest 200.
class ComplainHomeController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();

  static const sampleSize = 200;

  final statusCounts = <ChartPoint>[].obs;
  final categoryCounts = <ChartPoint>[].obs;
  final counts = <ComplaintStatus, int>{}.obs;
  final totalComplaints = 0.obs;
  final resolutionRate = 0.0.obs;

  /// True when there may be more complaints than the [sampleSize] counted.
  final isCapped = false.obs;

  int countOf(ComplaintStatus status) => counts[status] ?? 0;

  /// Open + in progress: what still needs a solver.
  int get activeCount =>
      countOf(ComplaintStatus.open) + countOf(ComplaintStatus.inProgress);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        final list = await _repository.adminComplaints(limit: sampleSize);
        // Only the categories this solver works on; the list above is already limited to them.
        var categories = ComplaintCategory.limitTo(
          await _repository.categories().catchError((_) => <ComplaintCategory>[]),
          await _repository.assignedCategoryIds(),
        );
        if (categories.isEmpty) {
          // Fall back to the categories seen in the complaints themselves.
          final seen = <int, String>{for (final c in list) c.categoryId: c.category};
          categories = [
            for (final e in seen.entries) ComplaintCategory(id: e.key, name: e.value),
          ];
        }

        totalComplaints.value = list.length;
        isCapped.value = list.length >= sampleSize;
        counts.assignAll({
          for (final s in ComplaintStatus.values)
            s: list.where((c) => c.status == s).length,
        });
        final done = countOf(ComplaintStatus.resolved) + countOf(ComplaintStatus.closed);
        resolutionRate.value = list.isEmpty ? 0.0 : done / list.length * 100;

        statusCounts.assignAll([
          for (final s in ComplaintStatus.values)
            ChartPoint(label: s.staffLabel, value: countOf(s).toDouble()),
        ]);
        categoryCounts.assignAll([
          for (final cat in categories)
            ChartPoint(
              label: cat.name,
              value: list.where((c) => c.categoryId == cat.id).length.toDouble(),
            ),
        ]);
      }, showLoading: showLoading);
}
