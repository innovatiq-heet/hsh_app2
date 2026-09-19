import 'package:get/get.dart';
import '../../abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';
import '../../network/responses/attendance/attendance_models.dart';

class AttendanceController extends GetxController
    with AadharResolvingMixin, LoadStateMixin {
  final AttendanceRepository _repository = Get.find();
  final FeesRepository _feesRepository = Get.find();
  final LaundryRepository _laundryRepository = Get.find();

  final todayStatus = <AttendanceType, DateTime?>{}.obs;
  final markingType = Rxn<AttendanceType>();
  final upcomingSabhas = <SabhaSession>[].obs;
  final activeDates = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    // Lazily ensure Aadhar is resolved for the session
    try {
      await resolveAadhar(
        fromFeeSummary: _feesRepository.resolveAadhar,
        fromLaundryBalance: () async =>
            (await _laundryRepository.balance()).studentAadhar,
      );
    } catch (_) {}

    final status = await _repository.todayStatus();
    todayStatus.assignAll(status);

    final sabhas = await _repository.upcomingSabhas();
    upcomingSabhas.assignAll(sabhas);

    final dates = await _repository.getActiveDates();
    activeDates.assignAll(dates);
  });

  /// Mark attendance directly or after a scan
  Future<AttendanceRecord?> mark(
    AttendanceType type, {
    required bool viaCode,
    String? qrToken,
  }) async {
    markingType.value = type;
    try {
      final result = await _repository.mark(
        MarkAttendanceRequest(
          type: type,
          viaCode: viaCode,
          qrToken: qrToken,
        ),
      );
      todayStatus[type] = result.time;
      todayStatus.refresh();
      return result;
    } finally {
      markingType.value = null;
    }
  }

  void onAttendanceMarked(AttendanceRecord record) {
    todayStatus[record.type] = record.time;
    todayStatus.refresh();
  }
}
