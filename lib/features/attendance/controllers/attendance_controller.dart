import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/enums/attendance_type.dart';
import '../../../core/models/student_profile/student_profile_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/attendance/attendance_repository.dart';
import '../../../core/network/repository/floors/floor_strings_repository.dart';
import '../../../core/network/repository/student_profile/student_profile_repository.dart';
import '../../../core/network/request/attendance/mark_attendance_request.dart';
import '../../../core/network/responses/attendance/attendance_models.dart';
import '../../../core/storage/session_store.dart';

class AttendanceController extends GetxController with LoadStateMixin {
  final AttendanceRepository _repository = Get.find();
  final FloorStringsRepository _floorStringsRepo = Get.find();

  static const String esp32ServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String attendanceServiceUuid =
      '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String floorTokenCharacteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  // Attendance state
  final alreadyMarked = false.obs;
  final attendanceActive = false.obs;
  final startTime = ''.obs;
  final endTime = ''.obs;
  final rawSchedules = <String, dynamic>{}.obs;

  // Per-session tracking map: sessionKey -> marked DateTime
  final todaySessionStatus = <String, DateTime?>{}.obs;
  final todaySessionPhases = <String, Set<int>>{}.obs;
  final todayStatus = <AttendanceType, DateTime?>{}.obs;
  final studentStatus = Rxn<StudentAttendanceStatus>();
  final schedulesList = <AttendanceScheduleItem>[].obs;
  final recentHistory = <AttendanceRecord>[].obs;
  final assignedFloor = 'Floor 9'.obs;
  final assignedRoom = 'Room 913'.obs;
  final markingType = Rxn<AttendanceType>();
  final markingSessionKey = ''.obs;
  final isMarking = false.obs;

  // Student Profile & Assigned Floor state
  final studentDetails = Rxn<StudentProfileModel>();
  final studentId = RxnInt();
  final isDetailsLoading = false.obs;
  final assignedFloorId = 9.obs;
  final assignedFloorName = 'Floor 9'.obs;
  final currentFloorServiceUuid = 'FLR9-64QN-XHW5'.obs;

  // Student identity details for Attendance Screen header
  final studentName = 'Harshil Vijaybhai Patel'.obs;
  final studentCode = '0987'.obs;
  final studentRoom = 'Room 913'.obs;
  final studentFloor = 'Floor 9'.obs;
  final studentGroup = 'Pavitra'.obs;
  final studentPhone = ''.obs;
  final isVerified = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Helper: Check if a specific session is marked today
  bool isSessionMarked(String sessionKey) {
    final key = sessionKey.toLowerCase().trim();
    return todaySessionStatus[key] != null;
  }

  /// Helper: Get marked timestamp for a specific session
  DateTime? getSessionMarkedTime(String sessionKey) {
    final key = sessionKey.toLowerCase().trim();
    return todaySessionStatus[key];
  }

  /// Load student profile details and resolve assigned floor
  Future<void> loadDetails({bool forceRefresh = false}) async {
    final store = Get.find<SessionStore>();
    final cached = store.currentStudentProfile;
    if (cached != null && !forceRefresh) {
      studentDetails.value = cached;
      _resolveFloorFromProfile(cached);
    }

    if (Get.isRegistered<StudentProfileRepository>()) {
      isDetailsLoading.value = true;
      try {
        final profileRepo = Get.find<StudentProfileRepository>();
        final aadhar = await store.cachedAadhar;
        final phone = await store.cachedPhone;
        final email = await store.email;
        final code = await store.cachedStudentCode;
        final name = await store.name;

        final profile = await profileRepo.fetchProfile(
          aadhar: aadhar,
          phone: phone,
          email: email,
          studentCode: code,
          name: name,
          forceRefresh: forceRefresh,
        );
        studentDetails.value = profile;
        _resolveFloorFromProfile(profile);
      } catch (e) {
        developer.log('loadDetails error: $e', name: 'AttendanceController');
      } finally {
        isDetailsLoading.value = false;
      }
    }
  }

  void _resolveFloorFromProfile(StudentProfileModel profile) {
    final room = profile.room;
    final fId = FloorStringsRepository.resolveFloorId(room: room);
    assignedFloorId.value = fId;
    assignedFloorName.value = _floorStringsRepo.getFloorNameSync(fId);
    Get.find<SessionStore>().cacheFloorId(fId);
    resolveAndLoadFloorString();
  }

  /// Dynamically fetch the floor service UUID for the assigned floor from API
  Future<void> resolveAndLoadFloorString() async {
    try {
      final item = await _floorStringsRepo.getFloorItem(assignedFloorId.value);
      currentFloorServiceUuid.value = item.stringValue;
      assignedFloorName.value = item.floorName;
    } catch (_) {}
  }

  String friendlyError(dynamic e) {
    final code = e is ApiException ? e.code?.toUpperCase().trim() : null;
    final raw = e.toString();
    final msg = raw.toLowerCase();

    if (code == 'NOT_ELIGIBLE_MISSED_FIRST' ||
        msg.contains('not eligible to mark second attendance') ||
        msg.contains('did not complete the first attendance')) {
      return 'You are not eligible for 2nd attendance because you missed 1st attendance.';
    }

    if (code == 'BETWEEN_ATTENDANCE_WINDOWS' ||
        code == 'FIRST_WINDOW_CLOSED' ||
        code == 'SECOND_WINDOW_CLOSED') {
      return e is ApiException && e.message.trim().isNotEmpty
          ? e.message
          : 'This attendance window is currently closed.';
    }

    if (code == 'LATE_LIMIT_EXCEEDED' || msg.contains('late_limit_exceeded')) {
      return 'You have exceeded the maximum allowed late days this month (10).';
    }

    if (msg.contains('already_marked') ||
        msg.contains('already marked') ||
        msg.contains('student_already_marked')) {
      if (e is ApiException && e.message.trim().isNotEmpty) {
        return e.message;
      }
      return 'Your attendance is already marked for this window.';
    }
    if (msg.contains('device_already_used')) {
      return 'This device has already been used to mark attendance today.';
    }
    if (msg.contains('no_active_session') ||
        msg.contains('no active') ||
        msg.contains('attendance is closed') ||
        msg.contains('session has ended')) {
      return 'Attendance is not open right now. Please check the schedule and try again during the allowed time.';
    }
    if (msg.contains('session has not started')) {
      return 'Attendance has not started yet. Please wait for the scheduled time.';
    }
    if (msg.contains('bluetooth') ||
        msg.contains('ble') ||
        msg.contains('gatt')) {
      return 'Could not connect to the attendance beacon. Make sure Bluetooth is turned on and you are close to your floor or global ESP-32.';
    }
    if (msg.contains('permission')) {
      return 'Bluetooth permissions are needed. Please allow them in your phone settings.';
    }
    if (msg.contains('turn on bluetooth') || msg.contains('adapter')) {
      return 'Please turn on Bluetooth to mark your attendance.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Connection timed out. Please move closer to your floor device and try again.';
    }
    if (msg.contains('could not find') || msg.contains('esp32')) {
      return 'Could not find the attendance beacon. Make sure you are near your floor ESP-32 or the Main Gate beacon and try again.';
    }
    if (msg.contains('floor')) {
      return raw.contains(': ')
          ? raw.substring(raw.indexOf(': ') + 2)
          : 'Please go near your floor ESP-32 beacon or the common entrance beacon and try again.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection refused')) {
      return 'Could not connect to the server. Please check your internet connection.';
    }

    String cleaned = raw
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '');
    if (cleaned.contains('(') ||
        cleaned.contains('/') ||
        (cleaned.contains('.') && cleaned.length > 80)) {
      return 'Something went wrong. Please try again or contact your floor leader for help.';
    }
    return cleaned;
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
    loadDetails(forceRefresh: !showLoading);
    try {
      final store = Get.find<SessionStore>();

      // 1. Fetch student status from backend
      final sStatus = await _repository.getStudentStatus();
      studentStatus.value = sStatus;
      alreadyMarked.value = sStatus.alreadyMarked;
      attendanceActive.value = sStatus.attendanceActive;
      startTime.value = sStatus.startTime;
      endTime.value = sStatus.endTime;
      rawSchedules.assignAll(sStatus.rawSchedules);

      // 2. Fetch all live attendance schedules and merge WITHOUT dropping
      // per-student two-phase status from /attendance/my-status.
      final liveSchedules = await _repository.fetchAttendanceSchedules(
        existingSchedules: sStatus.allSchedules,
      );

      final statusByKey = <String, AttendanceScheduleItem>{
        for (final item in sStatus.allSchedules)
          item.sessionKey.toLowerCase().trim(): item,
      };

      if (liveSchedules.isNotEmpty) {
        final merged = <AttendanceScheduleItem>[];
        final seenKeys = <String>{};
        for (final live in liveSchedules) {
          final key = live.sessionKey.toLowerCase().trim();
          seenKeys.add(key);
          merged.add(statusByKey[key] ?? live);
        }
        for (final extra in sStatus.allSchedules) {
          final key = extra.sessionKey.toLowerCase().trim();
          if (!seenKeys.contains(key)) {
            merged.add(extra);
          }
        }
        schedulesList.assignAll(merged);
      } else if (sStatus.allSchedules.isNotEmpty) {
        schedulesList.assignAll(sStatus.allSchedules);
      }

      // Rebuild today's status cleanly so Phase 1 alone never locks out Phase 2
      todaySessionStatus.clear();
      todaySessionPhases.clear();
      todayStatus.clear();

      final scheduleByKey = <String, AttendanceScheduleItem>{
        for (final s in schedulesList) s.sessionKey.toLowerCase().trim(): s,
      };

      // Record phase completions reported directly by /attendance/my-status
      for (final s in sStatus.allSchedules) {
        final key = s.sessionKey.toLowerCase().trim();
        final phases = todaySessionPhases.putIfAbsent(key, () => <int>{});
        if (s.hasMultipleAttendance) {
          if (s.isPhase1Marked) phases.add(1);
          if (s.isPhase2Marked) phases.add(2);
          if (s.isCompletedToday()) {
            final t = DateTime.tryParse(
                  s.secondAttendance?['marked_at']?.toString() ??
                      s.firstAttendance?['marked_at']?.toString() ??
                      '',
                ) ??
                DateTime.now();
            todaySessionStatus[key] = t;
            todayStatus[s.attendanceType] = t;
          }
        } else if (s.isCompletedToday()) {
          final t = DateTime.now();
          todaySessionStatus[key] = t;
          todayStatus[s.attendanceType] = t;
        }
      }

      // 3. Load locally cached attendance timestamp per single-phase session for today
      for (final s in schedulesList) {
        if (s.hasMultipleAttendance) continue;
        final key = s.sessionKey.toLowerCase().trim();
        final localMarkedTime = await store.getMarkedSessionTime(key);
        if (localMarkedTime != null) {
          todaySessionStatus[key] = localMarkedTime;
          todayStatus[s.attendanceType] = localMarkedTime;
        }
      }

      // 4. Fetch today's actual attendance records from backend history
      try {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final logs = await _repository.history(
          from: DateTime.parse(todayStr),
          to: DateTime.now(),
        );
        for (final log in logs) {
          final sKey = log.sessionKey.toLowerCase().trim();
          if (log.phase != null) {
            todaySessionPhases.putIfAbsent(sKey, () => <int>{}).add(log.phase!);
          }
          final matchedSched = scheduleByKey[sKey];
          final isMulti = matchedSched?.hasMultipleAttendance ?? false;
          if (!isMulti) {
            todaySessionStatus[sKey] = log.time;
            todayStatus[log.type] = log.time;
          } else {
            final phases = todaySessionPhases[sKey];
            final completeFromServer = matchedSched?.isCompletedToday() ?? false;
            if (completeFromServer || (phases != null && phases.contains(1) && phases.contains(2))) {
              todaySessionStatus[sKey] = log.time;
              todayStatus[log.type] = log.time;
            }
          }
        }
      } catch (_) {}

      // 5. If server status indicates an active session is marked, record it for that session
      if (sStatus.alreadyMarked && sStatus.activeSessionType != null) {
        final activeKey = sStatus.activeSessionType!.toLowerCase().trim();
        final matchedSched = scheduleByKey[activeKey];
        final isMulti = matchedSched?.hasMultipleAttendance ?? false;
        if ((!isMulti || (matchedSched?.isCompletedToday() ?? false)) &&
            todaySessionStatus[activeKey] == null) {
          todaySessionStatus[activeKey] = DateTime.now();
        }
      }

      todaySessionPhases.refresh();
      todaySessionStatus.refresh();
      todayStatus.refresh();

      // 6. Load assigned floor from session store room
      try {
        final room = await store.cachedRoom;
        if (room != null && room.isNotEmpty) {
          assignedRoom.value = room;
          final digits = room.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            final floorDigit = digits.length >= 3 ? digits[0] : digits;
            assignedFloor.value = 'Floor $floorDigit';
          }
        }
      } catch (_) {}

      // 7. Load recent 7-day attendance history summary
      try {
        final historyLogs = await _repository.history(
          from: DateTime.now().subtract(const Duration(days: 7)),
          to: DateTime.now(),
          limit: 10,
        );
        recentHistory.assignAll(historyLogs);
      } catch (_) {}

      // 8. Load student identity details for header card
      try {
        final sName = await store.name;
        if (sName != null && sName.trim().isNotEmpty) {
          studentName.value = sName.trim();
        }
        final sPhone = await store.cachedPhone;
        if (sPhone != null && sPhone.trim().isNotEmpty) {
          studentPhone.value = sPhone.trim();
        }
        final sCode = await store.cachedStudentCode;
        if (sCode != null && sCode.trim().isNotEmpty) {
          studentCode.value = sCode.trim();
        }
        final sRoom = await store.cachedRoom;
        if (sRoom != null && sRoom.trim().isNotEmpty) {
          studentRoom.value = sRoom.startsWith('Room') ? sRoom : 'Room $sRoom';
          assignedRoom.value = studentRoom.value;
          final digits = sRoom.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            final floorDigit = digits.length >= 3 ? digits[0] : digits;
            studentFloor.value = 'Floor $floorDigit';
            assignedFloor.value = 'Floor $floorDigit';
          }
        }

        final p = studentDetails.value;
        if (p != null) {
          if (p.fullName.trim().isNotEmpty) {
            studentName.value = p.fullName.trim();
          }
          if (p.phone.trim().isNotEmpty) {
            studentPhone.value = p.phone.trim();
          }
          if (p.bankCode.trim().isNotEmpty) {
            studentCode.value = p.bankCode.trim();
          }
          if (p.groupName.trim().isNotEmpty) {
            studentGroup.value = p.groupName.trim();
          }
          if (p.room.trim().isNotEmpty) {
            studentRoom.value = p.room.startsWith('Room')
                ? p.room
                : 'Room ${p.room}';
            assignedRoom.value = studentRoom.value;
            final digits = p.room.replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.isNotEmpty) {
              final floorDigit = digits.length >= 3 ? digits[0] : digits;
              studentFloor.value = 'Floor $floorDigit';
              assignedFloor.value = 'Floor $floorDigit';
            }
          }
        }
      } catch (_) {}
    } catch (_) {}
  }, showLoading: showLoading);

  /// Mark attendance directly or after a scan
  Future<AttendanceRecord?> mark(
    AttendanceType type, {
    String? sessionKey,
    required bool viaCode,
    String? qrToken,
    int? rssi,
  }) async {
    markingType.value = type;
    final effectiveKey = sessionKey ?? type.apiValue;
    try {
      final result = await _repository.mark(
        MarkAttendanceRequest(
          type: type,
          sessionKey: effectiveKey,
          viaCode: viaCode,
          qrToken: qrToken,
          rssi: rssi ?? -50,
          floorId: assignedFloorId.value,
          serviceUuid: currentFloorServiceUuid.value,
        ),
      );
      final key = effectiveKey.toLowerCase().trim();
      todaySessionStatus[key] = result.time;
      todaySessionStatus.refresh();
      todayStatus[type] = result.time;
      todayStatus.refresh();

      try {
        final store = Get.find<SessionStore>();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await store.saveLastAttendanceDate(today);
        await store.saveMarkedSessionDate(key, today);
        await store.saveMarkedSessionTime(key, result.time);
      } catch (_) {}

      await load(showLoading: false);
      return result;
    } finally {
      markingType.value = null;
    }
  }

  /// Connects to candidate ESP-32 and reads the floor string GATT characteristic
  Future<String?> _readFloorTokenFromDevice(BluetoothDevice device) async {
    final normService = attendanceServiceUuid.replaceAll('-', '').toLowerCase();
    final normChar = floorTokenCharacteristicUuid
        .replaceAll('-', '')
        .toLowerCase();

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 4),
        autoConnect: false,
      );
      final svcs = await device.discoverServices();
      for (final s in svcs) {
        final sNorm = s.uuid.toString().replaceAll('-', '').toLowerCase();
        if (sNorm != normService) continue;
        for (final c in s.characteristics) {
          final cNorm = c.uuid.toString().replaceAll('-', '').toLowerCase();
          if (cNorm == normChar) {
            final val = await c.read(timeout: 3);
            final tokenRead = String.fromCharCodes(val).trim();
            if (tokenRead.isNotEmpty) {
              return tokenRead;
            }
          }
        }
      }
    } catch (e) {
      developer.log(
        'Read floor token exception for ${device.remoteId}: $e',
        name: 'AttendanceController',
      );
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    return null;
  }

  /// Performs full BLE scanning and floor token verification matching reference project
  Future<AttendanceRecord?> markWithBle(
    AttendanceType type, {
    String? sessionKey,
    int? targetPhase,
  }) async {
    final effectiveKey = (sessionKey ?? type.apiValue).toLowerCase().trim();
    if (isMarking.value &&
        markingSessionKey.value.isNotEmpty &&
        markingSessionKey.value != effectiveKey) {
      return null;
    }
    markingType.value = type;
    markingSessionKey.value = effectiveKey;
    isMarking.value = true;

    try {
      // 1. Request Bluetooth Permissions on Android
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        if (statuses[Permission.bluetoothScan]?.isPermanentlyDenied == true ||
            statuses[Permission.bluetoothConnect]?.isPermanentlyDenied ==
                true) {
          throw Exception(
            'Bluetooth permissions are needed to detect your floor ESP-32. Please allow them in your phone settings.',
          );
        }
      }

      // 2. Ensure Bluetooth Adapter is Turned On
      BluetoothAdapterState adapterState;
      try {
        adapterState = await FlutterBluePlus.adapterState.first.timeout(
          const Duration(seconds: 3),
          onTimeout: () => BluetoothAdapterState.unknown,
        );
      } catch (_) {
        adapterState = BluetoothAdapterState.unknown;
      }

      if (adapterState != BluetoothAdapterState.on) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            adapterState = await FlutterBluePlus.adapterState.first.timeout(
              const Duration(seconds: 4),
              onTimeout: () => BluetoothAdapterState.off,
            );
          } catch (_) {}
        }
        if (adapterState != BluetoothAdapterState.on) {
          throw Exception('Please turn on Bluetooth to mark your attendance.');
        }
      }

      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      // Ensure student's expected floor string is freshly resolved from API
      await resolveAndLoadFloorString();

      final expectedFloorString = currentFloorServiceUuid.value.trim();
      final targetFloorId = assignedFloorId.value;
      final targetFloorName = assignedFloorName.value.isNotEmpty
          ? assignedFloorName.value
          : (targetFloorId == 0 ? 'Ground Floor' : 'Floor $targetFloorId');

      final normAttendanceService = attendanceServiceUuid
          .replaceAll('-', '')
          .toLowerCase();
      final expectedNorm = expectedFloorString
          .replaceAll('-', '')
          .toLowerCase();

      final candidateResults = <ScanResult>[];

      // 3. Scan for nearby ESP-32 attendance devices (floor-specific or global)
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final adv = r.advertisementData;
          final name =
              (r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : adv.advName)
                  .toLowerCase();
          final hasServiceUuid = adv.serviceUuids.any(
            (u) =>
                u.toString().replaceAll('-', '').toLowerCase() ==
                normAttendanceService,
          );
          final hasHostelName =
              name.contains('hostel') ||
              name.contains('esp32') ||
              name.contains('hams') ||
              name.contains('floor') ||
              name.contains('global') ||
              name.contains('gate') ||
              name.contains('sabha');

          if (hasServiceUuid || hasHostelName) {
            if (!candidateResults.any(
              (c) => c.device.remoteId == r.device.remoteId,
            )) {
              candidateResults.add(r);
            }
          }
        }
      });

      // Scan in low latency for 7 seconds to discover nearby floor/global devices
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 7),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      await FlutterBluePlus.isScanning
          .where((val) => val == false)
          .first
          .timeout(const Duration(seconds: 9), onTimeout: () => false);
      await scanSubscription.cancel();

      // Also gather devices from lastScanResults in case final packet arrived at stop
      for (final r in FlutterBluePlus.lastScanResults) {
        final adv = r.advertisementData;
        final name =
            (r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : adv.advName)
                .toLowerCase();
        final hasServiceUuid = adv.serviceUuids.any(
          (u) =>
              u.toString().replaceAll('-', '').toLowerCase() ==
              normAttendanceService,
        );
        final hasHostelName =
            name.contains('hostel') ||
            name.contains('esp32') ||
            name.contains('hams') ||
            name.contains('floor') ||
            name.contains('global') ||
            name.contains('gate') ||
            name.contains('sabha');

        if (hasServiceUuid || hasHostelName) {
          if (!candidateResults.any(
            (c) => c.device.remoteId == r.device.remoteId,
          )) {
            candidateResults.add(r);
          }
        }
      }

      if (candidateResults.isEmpty) {
        throw Exception(
          'Could not find an active attendance device. Please make sure you are on $targetFloorName or near the Main Entrance beacon, and Bluetooth is ON.',
        );
      }

      // Sort candidate devices by RSSI (strongest signal first)
      candidateResults.sort((a, b) => b.rssi.compareTo(a.rssi));

      bool floorStringMatched = false;
      String? detectedWrongFloorString;
      int matchedRssi = -50;

      // 4. Connect to candidate ESP-32 devices and read FLOOR_STRING characteristic
      for (final candidate in candidateResults) {
        String? readToken = await _readFloorTokenFromDevice(candidate.device);

        // Fallback: If GATT read didn't respond, inspect advertisement name
        if (readToken == null || readToken.isEmpty) {
          final advName =
              (candidate.device.platformName.isNotEmpty
                      ? candidate.device.platformName
                      : candidate.advertisementData.advName)
                  .trim()
                  .toLowerCase();

          if (advName.contains('global') ||
              advName.contains('all_floor') ||
              advName.contains('common')) {
            readToken = 'GLOBAL_ALL_FLOORS';
          } else if (advName.contains(expectedFloorString.toLowerCase()) ||
              advName.contains(expectedNorm) ||
              advName.contains('floor $targetFloorId') ||
              advName.contains('floor_$targetFloorId') ||
              advName.contains('floor-$targetFloorId')) {
            readToken = expectedFloorString;
          }
        }

        if (readToken != null && readToken.isNotEmpty) {
          final tokenUpper = readToken.trim().toUpperCase();
          final isGlobalToken =
              tokenUpper == 'GLOBAL' ||
              tokenUpper == 'GLOBAL_ALL_FLOORS' ||
              tokenUpper == 'HAMS_GLOBAL' ||
              tokenUpper == 'ACTIVE_ROOM_TOKEN' ||
              tokenUpper == 'ACTIVE_FLOOR_TOKEN' ||
              tokenUpper == 'ROOM_TOKEN' ||
              tokenUpper.contains('ACTIVE_ROOM') ||
              tokenUpper.contains('ACTIVE_FLOOR') ||
              tokenUpper.startsWith('GLOBAL_');

          final isTargetFloor =
              readToken.trim().toLowerCase() ==
              expectedFloorString.toLowerCase();

          if (isTargetFloor || isGlobalToken) {
            floorStringMatched = true;
            matchedRssi = candidate.rssi;
            break;
          } else {
            detectedWrongFloorString = readToken.trim();
          }
        }
      }

      // 5. Verification check
      if (!floorStringMatched) {
        if (detectedWrongFloorString != null &&
            detectedWrongFloorString.isNotEmpty) {
          throw Exception(
            "Floor Mismatch: You connected to a device with floor string '$detectedWrongFloorString', but you are assigned to $targetFloorName (token '$expectedFloorString'). Please go to $targetFloorName to mark attendance.",
          );
        } else {
          throw Exception(
            "Could not verify your floor token with the ESP-32 device. Please ensure you are on $targetFloorName near the floor device.",
          );
        }
      }

      // 6. Send attendance request to backend
      final result = await _repository.mark(
        MarkAttendanceRequest(
          type: type,
          sessionKey: effectiveKey,
          targetPhase: targetPhase,
          viaCode: false,
          rssi: matchedRssi,
          floorId: targetFloorId,
          serviceUuid: expectedFloorString,
        ),
      );

      // Determine whether this session requires two phases before marking as completely done
      final matchedSched = schedulesList.firstWhereOrNull(
        (s) => s.sessionKey.toLowerCase().trim() == effectiveKey,
      );
      final isMultiPhase = matchedSched?.hasMultipleAttendance ?? false;
      final markedPhase = result.phase ?? targetPhase;
      if (markedPhase != null) {
        todaySessionPhases.putIfAbsent(effectiveKey, () => <int>{}).add(markedPhase);
        todaySessionPhases.refresh();
      }
      final isSessionCompleted = !isMultiPhase ||
          markedPhase == 2 ||
          (todaySessionPhases[effectiveKey]?.containsAll({1, 2}) ?? false);

      // Save locally and update state
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (isSessionCompleted) {
        todaySessionStatus[effectiveKey] = result.time;
        todaySessionStatus.refresh();
        todayStatus[type] = result.time;
        todayStatus.refresh();
      }

      try {
        final store = Get.find<SessionStore>();
        await store.saveLastAttendanceDate(today);
        if (!isMultiPhase) {
          await store.saveMarkedSessionDate(effectiveKey, today);
          await store.saveMarkedSessionTime(effectiveKey, result.time);
        }
      } catch (_) {}

      await load(showLoading: false);
      return result;
    } finally {
      markingType.value = null;
      markingSessionKey.value = '';
      isMarking.value = false;
    }
  }

  void onAttendanceMarked(AttendanceRecord record) {
    final key = record.sessionKey.toLowerCase().trim();
    final matchedSched = schedulesList.firstWhereOrNull(
      (s) => s.sessionKey.toLowerCase().trim() == key,
    );
    final isMultiPhase = matchedSched?.hasMultipleAttendance ?? false;
    if (record.phase != null) {
      todaySessionPhases.putIfAbsent(key, () => <int>{}).add(record.phase!);
      todaySessionPhases.refresh();
    }
    final isSessionCompleted = !isMultiPhase ||
        record.phase == 2 ||
        (todaySessionPhases[key]?.containsAll({1, 2}) ?? false);

    if (isSessionCompleted) {
      todaySessionStatus[key] = record.time;
      todaySessionStatus.refresh();
      todayStatus[record.type] = record.time;
      todayStatus.refresh();
      alreadyMarked.value = true;
    }
    recentHistory.insert(0, record);
    recentHistory.refresh();
  }
}
