import 'package:get/get.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/responses/attendance/attendance_responses.dart';

class AttendanceHistoryController extends GetxController {
  final AttendanceRepository _repository = Get.find();

  final isLoading = true.obs;
  final entries = <AttendanceLogEntry>[].obs;
  final Rxn<AttendanceType> typeFilter = Rxn<AttendanceType>();
  final Rxn<DateTime> fromDate = Rxn<DateTime>();
  final Rxn<DateTime> toDate = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    entries.assignAll(
      await _repository.history(
        from: fromDate.value,
        to: toDate.value,
        type: typeFilter.value,
      ),
    );
    isLoading.value = false;
  }

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
