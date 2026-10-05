import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/network/repository/geofence/geofence_repository.dart';
import '../../../core/utils/app_snackbar.dart';

/// Warden view of every student's last reported phone location.
///
/// Phones report a fix every warden-configured interval (1–10 min, set on the
/// Campus Geofence screen), so the list refreshes itself every minute while open.
class StudentLocationsController extends GetxController {
  static const _refreshInterval = Duration(minutes: 1);

  final GeofenceRepository _repository = GeofenceRepository();

  final RxList<StudentLocation> students = <StudentLocation>[].obs;
  final RxBool isLoading = false.obs;
  final RxString loadError = ''.obs;
  final RxString query = ''.obs;

  /// null = all students.
  final Rx<LocationStatus?> filter = Rx<LocationStatus?>(null);

  final searchController = TextEditingController();
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    load();
    _timer = Timer.periodic(_refreshInterval, (_) => load(silent: true));
  }

  @override
  void onClose() {
    _timer?.cancel();
    searchController.dispose();
    super.onClose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) isLoading.value = students.isEmpty;
    try {
      students.assignAll(await _repository.fetchStudentLocations());
      loadError.value = '';
    } catch (e) {
      debugPrint('[StudentLocations] load error: $e');
      if (students.isEmpty) loadError.value = 'Could not load student locations. Pull to retry.';
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(LocationStatus? status) => filter.value = status;

  int countOf(LocationStatus status) => students.where((s) => s.status == status).length;

  /// Filtered by status and search; students outside campus first, then by name.
  List<StudentLocation> get visible {
    final q = query.value.trim().toLowerCase();
    final f = filter.value;
    final list = students.where((s) {
      if (f != null && s.status != f) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.room.toLowerCase().contains(q) ||
          s.studentCode.toLowerCase().contains(q) ||
          s.phone.contains(q);
    }).toList()
      ..sort((a, b) {
        final byStatus = a.status.index.compareTo(b.status.index);
        return byStatus != 0 ? byStatus : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  Future<void> openInMaps(StudentLocation student) async {
    final loc = student.location;
    if (loc == null) return;
    final ok = await launchUrl(loc.mapsUri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok) AppSnackbar.error('Maps Error', 'Could not open the map for ${student.name}.');
  }

  Future<void> callStudent(StudentLocation student) async {
    if (student.phone.trim().isEmpty) {
      AppSnackbar.warning('No Number', 'Student mobile number is not available.');
      return;
    }
    final ok = await launchUrl(Uri(scheme: 'tel', path: student.phone.trim())).catchError((_) => false);
    if (!ok) AppSnackbar.error('Call Error', 'Could not open the phone dialer.');
  }
}
