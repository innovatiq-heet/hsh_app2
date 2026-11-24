import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/geofence/student_location.dart';
import '../../../core/network/repository/geofence/geofence_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../phonebook/widgets/alpha_scroll_rail.dart';

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
  final scrollController = ScrollController();
  final listController = ListController();

  final RxBool isMapView = false.obs;
  final RxBool sortByName = false.obs;
  final RxMap<String, int> alphaIndex = <String, int>{}.obs;
  final RxList<RailEntry> railEntries = <RailEntry>[].obs;
  final Rx<StudentLocation?> selectedStudent = Rx<StudentLocation?>(null);
  final RxList<Map<String, dynamic>> selectedStudentTrail = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingTrail = false.obs;
  final RxBool isAlerting = false.obs;

  void toggleViewMode() {
    isMapView.toggle();
    if (!isMapView.value) {
      selectedStudent.value = null;
      selectedStudentTrail.clear();
    }
  }

  Future<void> selectStudent(StudentLocation? student) async {
    selectedStudent.value = student;
    selectedStudentTrail.clear();
    if (student == null) return;

    isLoadingTrail.value = true;
    try {
      final history = await _repository.fetchLocationHistory(student.studentId, limit: 30);
      selectedStudentTrail.assignAll(history);
    } catch (e) {
      debugPrint('[StudentLocations] load trail error: $e');
    } finally {
      isLoadingTrail.value = false;
    }
  }

  Future<void> alertAllOutside() async {
    final outsideCount = countOf(LocationStatus.outside);
    if (outsideCount == 0) {
      AppSnackbar.info('No Students Outside', 'All active students are currently inside campus.');
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Alert Outside Students'),
          ],
        ),
        content: Text(
          'Send an urgent curfew push notification to all $outsideCount students currently outside campus perimeter?',
          style: const TextStyle(fontSize: 14.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    isAlerting.value = true;
    try {
      final res = await _repository.alertAllOutside();
      final sentCount = res['sentCount'] ?? 0;
      final total = res['totalOutside'] ?? outsideCount;
      AppSnackbar.success(
        'Alerts Dispatched',
        'Delivered curfew warnings to $sentCount of $total outside students.',
      );
    } catch (e) {
      debugPrint('[StudentLocations] alert error: $e');
      AppSnackbar.error('Alert Failed', 'Could not dispatch notifications to outside students.');
    } finally {
      isAlerting.value = false;
    }
  }

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && (args['map'] == true || args['view'] == 'map')) {
      isMapView.value = true;
    }
    load();
    _timer = Timer.periodic(_refreshInterval, (_) => load(silent: true));

    ever(students, (_) => _rebuildAlphaIndex());
    ever(filter, (_) => _rebuildAlphaIndex());
    ever(sortByName, (_) => _rebuildAlphaIndex());
    debounce(query, (_) => _rebuildAlphaIndex(), time: const Duration(milliseconds: 150));
  }

  @override
  void onClose() {
    _timer?.cancel();
    searchController.dispose();
    scrollController.dispose();
    listController.dispose();
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
      _rebuildAlphaIndex();
    }
  }

  void setFilter(LocationStatus? status) {
    filter.value = status;
    _rebuildAlphaIndex();
  }

  void toggleSortByName() {
    sortByName.toggle();
    _rebuildAlphaIndex();
  }

  int countOf(LocationStatus status) => students.where((s) => s.status == status).length;

  /// Filtered by status and search; students outside campus first, then by name (or A-Z if sortByName).
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
        if (sortByName.value) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        final byStatus = a.status.index.compareTo(b.status.index);
        return byStatus != 0 ? byStatus : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  String letterOf(String name) {
    final trimmed = name.trimLeft();
    if (trimmed.isEmpty) return '#';
    final first = trimmed[0].toUpperCase();
    final code = first.codeUnitAt(0);
    if (code >= 65 && code <= 90) return first;
    return '#';
  }

  void _rebuildAlphaIndex() {
    final list = visible;
    final Map<String, int> index = {};
    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      final letter = letterOf(s.name);
      index.putIfAbsent(letter, () => i);
    }
    alphaIndex.assignAll(index);

    final letters = index.keys.toList();
    letters.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    railEntries.assignAll(
      letters.map((l) => RailEntry(l, alumni: false)),
    );
  }

  /// Jumps straight to the first student of a rail letter.
  void scrollToRailEntry(RailEntry entry) {
    if (!sortByName.value) {
      sortByName.value = true;
      _rebuildAlphaIndex();
    }
    final index = alphaIndex[entry.letter];
    if (index == null || !scrollController.hasClients) return;
    if (listController.isAttached) {
      listController.jumpToItem(
        index: index,
        scrollController: scrollController,
        alignment: 0,
      );
    }
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
