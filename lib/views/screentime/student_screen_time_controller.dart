import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common_enums/user_role.dart';
import '../../network/api_client.dart';
import '../../storage/session_store.dart';

class StudentScreenTimeController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final RxBool isLoading = false.obs;
  final RxBool isSearching = false.obs;
  final RxBool isOnline = false.obs;
  final RxBool isScreenOn = false.obs;
  final RxString currentApp = ''.obs;
  final RxInt totalMinutesToday = 0.obs;
  final RxInt nightMinutesToday = 0.obs;
  final RxList<dynamic> appBreakdown = <dynamic>[].obs;
  final RxList<dynamic> historyRecords = <dynamic>[].obs;

  final searchAadharController = TextEditingController();
  final RxString targetedAadhar = ''.obs;
  final Rx<UserRole> currentRole = UserRole.student.obs;

  Timer? _heartbeatTimer;

  @override
  void onInit() {
    super.onInit();
    _loadRole();
    startHeartbeatTimer();
  }

  @override
  void onClose() {
    _heartbeatTimer?.cancel();
    searchAadharController.dispose();
    super.onClose();
  }

  Future<void> _loadRole() async {
    final role = await SessionStore.instance.role;
    currentRole.value = role;
    await fetchLiveStatus();
    await fetchHistory();
  }

  /// Start periodic 10-minute ping from device
  void startHeartbeatTimer() {
    pingHeartbeat();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      pingHeartbeat();
    });
  }

  /// 10-minute heartbeat ping to backend
  Future<void> pingHeartbeat() async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final currentAppName = Platform.isAndroid ? 'com.hsh.hostelapp' : 'com.apple.mobilesafari';

      final dummyBreakdown = [
        {'packageName': 'com.google.android.youtube', 'appName': 'YouTube', 'minutes': 35},
        {'packageName': 'com.whatsapp', 'appName': 'WhatsApp', 'minutes': 25},
        {'packageName': 'com.instagram.android', 'appName': 'Instagram', 'minutes': 20},
        {'packageName': 'com.hsh.hostelapp', 'appName': 'Hostel Portal', 'minutes': 15},
      ];

      final total = dummyBreakdown.fold<int>(0, (sum, item) => sum + (item['minutes'] as int));

      await _apiClient.dio.post('/screen-time/ping', data: {
        'date': dateStr,
        'totalScreenTimeMinutes': total,
        'isScreenOn': true,
        'currentApp': currentAppName,
        'appUsageBreakdown': dummyBreakdown,
      });
    } catch (e) {
      debugPrint('[ScreenTime] Ping error: $e');
    }
  }

  /// Fetch live status (for self or targeted student aadhar)
  Future<void> fetchLiveStatus([String? aadhar]) async {
    isLoading.value = true;
    try {
      final queryAadhar = aadhar ?? targetedAadhar.value;
      final endpoint = queryAadhar.isNotEmpty
          ? '/screen-time/live/$queryAadhar'
          : '/screen-time/live';

      final response = await _apiClient.dio.get(endpoint);
      final data = response.data['data'] ?? response.data;

      if (data != null) {
        isOnline.value = data['isOnline'] ?? false;
        isScreenOn.value = data['isScreenOn'] ?? false;
        currentApp.value = data['currentApp'] ?? 'Idle';
        totalMinutesToday.value = data['totalScreenTimeMinutes'] ?? 0;
        nightMinutesToday.value = data['nightScreenTimeMinutes'] ?? 0;
        appBreakdown.assignAll(data['appUsageBreakdown'] ?? []);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchLiveStatus error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch history logs
  Future<void> fetchHistory([String? aadhar]) async {
    try {
      final queryAadhar = aadhar ?? targetedAadhar.value;
      final endpoint = queryAadhar.isNotEmpty
          ? '/screen-time/history/$queryAadhar'
          : '/screen-time/history';

      final response = await _apiClient.dio.get(endpoint);
      final data = response.data['data'] ?? response.data;
      if (data != null && data['records'] != null) {
        historyRecords.assignAll(data['records']);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchHistory error: $e');
    }
  }

  /// Leader searches another student's screen time by Aadhar
  void searchStudent() {
    final aadhar = searchAadharController.text.trim();
    targetedAadhar.value = aadhar;
    fetchLiveStatus(aadhar);
    fetchHistory(aadhar);
  }

  /// Clear targeted student search and view own screen time
  void clearSearch() {
    searchAadharController.clear();
    targetedAadhar.value = '';
    fetchLiveStatus();
    fetchHistory();
  }
}
