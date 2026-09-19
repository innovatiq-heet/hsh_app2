import 'package:get/get.dart';
import '../../abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/attendance_type.dart';
import '../../network/repository/attendance/attendance_repository.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/attendance/mark_attendance_request.dart';
import '../../network/responses/attendance/attendance_responses.dart';
import '../../utils/date_formatting.dart';

class AttendanceController extends GetxController
    with AadharResolvingMixin, LoadStateMixin {
  final AttendanceRepository _repository = Get.find();
  final FeesRepository _feesRepository = Get.find();
  final LaundryRepository _laundryRepository = Get.find();

  final todayStatus = <AttendanceType, DateTime?>{}.obs;
  final markingType = Rxn<AttendanceType>();
  final upcomingSabhas = <SabhaResponse>[].obs;

  /// Current month's log (previous days); today is tracked by [todayStatus].
  final monthLog = <AttendanceLogEntry>[].obs;

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
    final now = DateTime.now();
    final results = await Future.wait([
      _repository.todayStatus(),
      _repository.upcomingSabhas(),
      _repository.history(from: DateTime(now.year, now.month).toUtc()),
    ]);
    todayStatus.assignAll(results[0] as Map<AttendanceType, DateTime?>);
    upcomingSabhas.assignAll(results[1] as List<SabhaResponse>);
    monthLog.assignAll(results[2] as List<AttendanceLogEntry>);
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

  int get markedToday => todayStatus.values.where((v) => v != null).length;

  /// Sessions marked per IST day-of-month for the current month.
  Map<int, int> get sessionsByDay {
    final today = DateFormatting.utcToIst(DateTime.now().toUtc());
    final counts = <int, int>{};
    for (final entry in monthLog) {
      final ist = DateFormatting.utcToIst(entry.markedAt);
      if (ist.year != today.year || ist.month != today.month) continue;
      if (ist.day == today.day) continue;
      counts[ist.day] = (counts[ist.day] ?? 0) + 1;
    }
    if (markedToday > 0) counts[today.day] = markedToday;
    return counts;
  }

  /// Consecutive days with at least one session, ending today (or
  /// yesterday, if nothing is marked yet today).
  int get currentStreak {
    final counts = sessionsByDay;
    var day = DateFormatting.utcToIst(DateTime.now().toUtc()).day;
    if ((counts[day] ?? 0) == 0) day--;
    var streak = 0;
    while (day >= 1 && (counts[day] ?? 0) > 0) {
      streak++;
      day--;
    }
    return streak;
  }
}
