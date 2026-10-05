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

  /// Options offered for how often student phones take a location fix.
  static const locationIntervalOptions = [1, 2, 5, 10];

  Future<void> updateLocationInterval(int minutes) async {
    if (minutes == policy.value.checkIntervalMinutes) return;
    await _savePolicy(
      policy.value.copyWith(checkIntervalMinutes: minutes),
      success: ('Location Updates', 'Student phones now report their location every $minutes min.'),
    );
  }

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

  /// 🟢 Gate pass: backend stores the pass; the phone picks it up on its next
  /// policy poll (~30 s), stops enforcing the curfew and releases a breach lock.
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
    (String, String)? success,
  }) async {
    final prevAction = breach.actionTaken;
    final prevResolved = breach.isResolved;
    breach.actionTaken = action;
    if (resolves) breach.isResolved = true;
    breachLogs.refresh();

    try {
      final result = await _repository.recordAdminAction(
        breachId: breach.id,
        studentId: breach.studentId,
        action: action,
        gatePassHours: gatePassHours,
      );
      if (action == BreachActionStatus.warningSent && result['notified'] != true) {
        AppSnackbar.warning(
          'Warning Not Delivered',
          '${breach.studentName}\'s phone isn\'t registered for notifications. Please call instead.',
        );
      } else if (success != null) {
        AppSnackbar.success(success.$1, success.$2);
      }
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
