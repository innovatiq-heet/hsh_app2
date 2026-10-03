import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/geofence/geofence_breach_event.dart';
import '../../../core/models/geofence/geofence_policy_model.dart';
import '../../../core/network/repository/geofence/geofence_repository.dart';
import '../../../core/utils/app_snackbar.dart';

class AdminGeofenceController extends GetxController {
  final GeofenceRepository _repository = GeofenceRepository();

  final Rx<GeofencePolicyModel> policy = const GeofencePolicyModel().obs;
  final RxList<GeofenceBreachEvent> breachLogs = <GeofenceBreachEvent>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString loadError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = breachLogs.isEmpty;
    loadError.value = '';
    try {
      final results = await Future.wait([
        _repository.fetchPolicy(),
        _repository.fetchBreachLogs(),
      ]);
      policy.value = results[0] as GeofencePolicyModel;
      breachLogs.assignAll(results[1] as List<GeofenceBreachEvent>);
    } catch (e) {
      debugPrint('[AdminGeofence] loadData error: $e');
      loadError.value = 'Could not load geofence data. Pull to retry.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Whether current local time is inside curfew restriction window
  bool get isCurfewActiveNow => policy.value.isWithinCurfew(DateTime.now());

  List<GeofenceBreachEvent> get activeBreaches =>
      breachLogs.where((e) => !e.isResolved).toList();

  List<GeofenceBreachEvent> get resolvedLogs =>
      breachLogs.where((e) => e.isResolved).toList();

  // ---------- Policy ----------

  Future<void> updateCurfewTimes(TimeOfDay start, TimeOfDay end) async {
    if (start == end) {
      AppSnackbar.warning('Invalid Curfew', 'Start and end time cannot be the same.');
      return;
    }
    await _savePolicy(
      policy.value.copyWith(startTime: start, endTime: end),
      success: ('Curfew Updated', 'Curfew now runs ${policy.value.copyWith(startTime: start, endTime: end).formatTimeRange()}.'),
    );
  }

  Future<void> toggleGeofence(bool enabled) => _savePolicy(
        policy.value.copyWith(isActive: enabled),
        success: enabled
            ? ('Geofencing Active', 'Campus perimeter is monitored during curfew.')
            : ('Geofencing Paused', 'Perimeter monitoring is off until re-enabled.'),
      );

  Future<void> toggleLockOnBreach(bool enabled) => _savePolicy(
        policy.value.copyWith(enforcePhoneLock: enabled),
        success: enabled
            ? ('Auto-lock On', 'Phones lock automatically while outside campus during curfew.')
            : ('Auto-lock Off', 'Breaches are reported but phones stay usable.'),
      );

  Future<void> _savePolicy(GeofencePolicyModel updated, {required (String, String) success}) async {
    final previous = policy.value;
    policy.value = updated; // optimistic
    isSaving.value = true;
    try {
      await _repository.savePolicy(updated);
      AppSnackbar.success(success.$1, success.$2);
    } catch (e) {
      policy.value = previous;
      debugPrint('[AdminGeofence] savePolicy error: $e');
      AppSnackbar.error('Not Saved', 'Could not reach the server. Curfew settings are unchanged.');
    } finally {
      isSaving.value = false;
    }
  }

  // ---------- Breach actions ----------

  /// 🔒 Remote-lock the student's phone (keeps their other screen-time rules).
  Future<void> remoteLockStudentPhone(GeofenceBreachEvent breach) => _act(
        breach,
        BreachActionStatus.phoneLocked,
        resolves: true,
        before: () => _repository.lockStudentPhone(breach.studentId),
        success: ('Device Locked', '${breach.studentName}\'s phone locks within about 30 seconds.'),
      );

  /// 📞 Call the student.
  Future<void> callStudent(GeofenceBreachEvent breach) =>
      _call(breach, breach.phone, BreachActionStatus.calledStudent, 'Student mobile number is not available.');

  /// 👨‍👩‍👧 Call the parent / guardian.
  Future<void> callParent(GeofenceBreachEvent breach) =>
      _call(breach, breach.parentPhone, BreachActionStatus.calledParent, 'Parent contact is not available.');

  /// ⚠️ Official in-app curfew warning (delivered by the backend).
  Future<void> sendCurfewWarning(GeofenceBreachEvent breach) => _act(
        breach,
        BreachActionStatus.warningSent,
        success: ('Warning Sent', 'Curfew warning queued for ${breach.studentName}.'),
      );

  /// 🟢 Gate pass: backend sets `exemptUntil` so the phone stops reporting.
  Future<void> grantTemporaryGatePass(GeofenceBreachEvent breach, int hours) => _act(
        breach,
        BreachActionStatus.gatePassGranted,
        resolves: true,
        gatePassHours: hours,
        success: ('Gate Pass Granted', '${breach.studentName} may be outside for the next $hours h.'),
      );

  Future<void> dismissBreach(GeofenceBreachEvent breach) =>
      _act(breach, BreachActionStatus.dismissed, resolves: true);

  Future<void> _call(GeofenceBreachEvent breach, String number, BreachActionStatus action, String missingMsg) async {
    if (number.trim().isEmpty) {
      AppSnackbar.warning('No Number', missingMsg);
      return;
    }
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: number.trim()));
      if (!launched) throw Exception('no dialer');
    } catch (_) {
      AppSnackbar.error('Call Error', 'Could not open the phone dialer.');
      return;
    }
    await _act(breach, action);
  }

  /// Applies an action optimistically, persists it, then re-syncs from the
  /// server so every warden sees the same state. Rolls back on failure.
  Future<void> _act(
    GeofenceBreachEvent breach,
    BreachActionStatus action, {
    bool resolves = false,
    int? gatePassHours,
    Future<void> Function()? before,
    (String, String)? success,
  }) async {
    final prevAction = breach.actionTaken;
    final prevResolved = breach.isResolved;
    breach.actionTaken = action;
    if (resolves) breach.isResolved = true;
    breachLogs.refresh();

    try {
      if (before != null) await before();
      await _repository.recordAdminAction(
        breachId: breach.id,
        studentId: breach.studentId,
        action: action,
        gatePassHours: gatePassHours,
      );
      if (success != null) AppSnackbar.success(success.$1, success.$2);
      loadData();
    } catch (e) {
      breach.actionTaken = prevAction;
      breach.isResolved = prevResolved;
      breachLogs.refresh();
      debugPrint('[AdminGeofence] action ${action.name} failed: $e');
      AppSnackbar.error('Action Failed', 'Could not record "${_label(action)}". Please try again.');
    }
  }

  static String _label(BreachActionStatus a) => switch (a) {
        BreachActionStatus.phoneLocked => 'Lock phone',
        BreachActionStatus.calledStudent => 'Call student',
        BreachActionStatus.calledParent => 'Call parent',
        BreachActionStatus.warningSent => 'Send warning',
        BreachActionStatus.gatePassGranted => 'Gate pass',
        BreachActionStatus.dismissed => 'Dismiss',
        BreachActionStatus.none => 'None',
      };
}
