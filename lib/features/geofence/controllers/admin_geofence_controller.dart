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

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;
    try {
      final p = await _repository.fetchPolicy();
      policy.value = p;
      final logs = await _repository.fetchBreachLogs();
      breachLogs.assignAll(logs);
    } catch (e) {
      debugPrint('[AdminGeofence] loadData error: $e');
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

  /// Update Curfew active start & end times
  Future<void> updateCurfewTimes(TimeOfDay start, TimeOfDay end) async {
    isSaving.value = true;
    try {
      final updated = policy.value.copyWith(startTime: start, endTime: end);
      await _repository.savePolicy(updated);
      policy.value = updated;
      AppSnackbar.success(
        'Curfew Updated',
        'Geofence curfew schedule set to ${updated.formatTimeRange()}',
      );
    } catch (e) {
      AppSnackbar.error('Save Failed', 'Could not update curfew: $e');
    } finally {
      isSaving.value = false;
    }
  }

  /// Toggle Geofencing Active / Inactive
  Future<void> toggleGeofence(bool enabled) async {
    try {
      final updated = policy.value.copyWith(isActive: enabled);
      await _repository.savePolicy(updated);
      policy.value = updated;
      if (enabled) {
        AppSnackbar.success('Geofencing Active', 'Hostel perimeter monitoring enabled.');
      } else {
        AppSnackbar.info('Geofencing Paused', 'Perimeter tracking has been temporarily disabled.');
      }
    } catch (e) {
      AppSnackbar.error('Toggle Failed', '$e');
    }
  }

  /// 🔒 Action 1: Remote Lock Student Phone
  Future<void> remoteLockStudentPhone(GeofenceBreachEvent breach) async {
    try {
      await _repository.recordAdminAction(
        breachId: breach.id,
        studentId: breach.studentId,
        action: BreachActionStatus.phoneLocked,
      );
      breach.actionTaken = BreachActionStatus.phoneLocked;
      breach.isResolved = true;
      breachLogs.refresh();

      AppSnackbar.success(
        'Device Locked 🔒',
        '${breach.studentName}\'s phone has been remotely locked via Hostel Screen Time enforcement.',
      );
    } catch (e) {
      AppSnackbar.error('Remote Lock Failed', '$e');
    }
  }

  /// 📞 Action 2: Call Student Directly
  Future<void> callStudent(GeofenceBreachEvent breach) async {
    if (breach.phone.isEmpty) {
      AppSnackbar.warning('No Phone Number', 'Student mobile number is not available.');
      return;
    }

    final uri = Uri.parse('tel:${breach.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await _repository.recordAdminAction(
        breachId: breach.id,
        studentId: breach.studentId,
        action: BreachActionStatus.calledStudent,
      );
      breach.actionTaken = BreachActionStatus.calledStudent;
      breachLogs.refresh();
    } else {
      AppSnackbar.error('Call Error', 'Could not open phone dialer.');
    }
  }

  /// 👨‍👩‍👧 Action 3: Call Parent / Guardian
  Future<void> callParent(GeofenceBreachEvent breach) async {
    if (breach.parentPhone.isEmpty) {
      AppSnackbar.warning('No Parent Contact', 'Parent emergency contact is not available.');
      return;
    }

    final uri = Uri.parse('tel:${breach.parentPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await _repository.recordAdminAction(
        breachId: breach.id,
        studentId: breach.studentId,
        action: BreachActionStatus.calledParent,
      );
      breach.actionTaken = BreachActionStatus.calledParent;
      breachLogs.refresh();
    } else {
      AppSnackbar.error('Call Error', 'Could not open phone dialer.');
    }
  }

  /// ⚠️ Action 4: Send Official In-App Curfew Warning
  Future<void> sendCurfewWarning(GeofenceBreachEvent breach) async {
    try {
      await _repository.recordAdminAction(
        breachId: breach.id,
        studentId: breach.studentId,
        action: BreachActionStatus.warningSent,
      );
      breach.actionTaken = BreachActionStatus.warningSent;
      breachLogs.refresh();

      AppSnackbar.info(
        'Warning Dispatched ⚠️',
        'Urgent curfew warning notification sent to ${breach.studentName}\'s screen.',
      );
    } catch (e) {
      AppSnackbar.error('Failed to Send Warning', '$e');
    }
  }

  /// 🟢 Action 5: Grant Temporary Gate Pass (Allow excursion)
  Future<void> grantTemporaryGatePass(GeofenceBreachEvent breach, int hours) async {
    try {
      await _repository.recordAdminAction(
        breachId: breach.id,
        studentId: breach.studentId,
        action: BreachActionStatus.gatePassGranted,
      );
      breach.actionTaken = BreachActionStatus.gatePassGranted;
      breach.isResolved = true;
      breachLogs.refresh();

      AppSnackbar.success(
        'Gate Pass Granted 🟢',
        'Authorized $hours-hour gate pass granted for ${breach.studentName}.',
      );
    } catch (e) {
      AppSnackbar.error('Error Granting Pass', '$e');
    }
  }

  /// Dismiss alert
  Future<void> dismissBreach(GeofenceBreachEvent breach) async {
    await _repository.recordAdminAction(
      breachId: breach.id,
      studentId: breach.studentId,
      action: BreachActionStatus.dismissed,
    );
    breach.actionTaken = BreachActionStatus.dismissed;
    breach.isResolved = true;
    breachLogs.refresh();
  }
}
