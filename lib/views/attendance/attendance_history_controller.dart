import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/responses/attendance/attendance_models.dart';

class AttendanceHistoryController extends GetxController with LoadStateMixin {
  final AttendanceRepository _repository = Get.find();

  final entries = <AttendanceRecord>[].obs;
  final Rxn<AttendanceType> typeFilter = Rxn<AttendanceType>();
  final Rxn<DateTime> fromDate = Rxn<DateTime>();
  final Rxn<DateTime> toDate = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    final list = await _repository.history(
      from: fromDate.value,
      to: toDate.value,
      type: typeFilter.value,
      limit: 50,
    );
    entries.assignAll(list);
  });

  void setTypeFilter(AttendanceType? type) {
    typeFilter.value = type;
    load();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    fromDate.value = from;
    toDate.value = to;
    load();
  }

  void clearFilters() {
    typeFilter.value = null;
    fromDate.value = null;
    toDate.value = null;
    load();
  }
}
