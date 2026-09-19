import 'package:get/get.dart';
import '../../abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';
import '../../network/responses/attendance/attendance_responses.dart';

class AttendanceController extends GetxController
    with AadharResolvingMixin, LoadStateMixin {
  final AttendanceRepository _repository = Get.find();
  final FeesRepository _feesRepository = Get.find();
  final LaundryRepository _laundryRepository = Get.find();

  final todayStatus = <AttendanceType, DateTime?>{}.obs;
  final markingType = Rxn<AttendanceType>();
  final upcomingSabhas = <SabhaResponse>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    await resolveAadhar(
      fromFeeSummary: _feesRepository.resolveAadhar,
      fromLaundryBalance: () async =>
          (await _laundryRepository.balance()).studentAadhar,
    );
    final status = await _repository.todayStatus();
    todayStatus.assignAll(status);
    upcomingSabhas.assignAll(await _repository.upcomingSabhas());
  });

  Future<void> mark(AttendanceType type, {required bool viaCode}) async {
    if (todayStatus[type] != null) return;
    markingType.value = type;
    try {
      final result = await _repository.mark(
        MarkAttendanceRequest(type: type, viaCode: viaCode),
      );
      todayStatus[type] = result.markedAt;
      todayStatus.refresh();
    } finally {
      markingType.value = null;
    }
  }
}
