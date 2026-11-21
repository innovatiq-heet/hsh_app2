import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../whatsapp_accounts/widgets/send_from_sheet.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/birthday/birthday_models.dart';
import '../../../core/network/repository/birthday/birthday_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../models/parent_birthday.dart';
import '../../phonebook/services/phonebook_database_service.dart';
import '../../phonebook/services/phonebook_sync_service.dart';

class AdminBirthdayController extends GetxController {
  final BirthdayRepository _repository = BirthdayRepository();

  final Rxn<BirthdayDashboardData> dashboard = Rxn<BirthdayDashboardData>();
  final RxList<BirthdayStudentModel> allStudents = <BirthdayStudentModel>[].obs;

  final RxBool isLeader = (Get.isRegistered<SessionStore>() && Get.find<SessionStore>().isLeader).obs;
  final RxnString leaderGroup = RxnString(
    Get.isRegistered<SessionStore>()
        ? Get.find<SessionStore>().currentSession?.studentProfile?.groupName
        : null,
  );
  final RxString leaderTemplate = ''.obs;
  final TextEditingController leaderTemplateController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isTriggering = false.obs;
  final RxBool hasSentToday = false.obs;
  final RxBool isLoadingStudents = false.obs;
  final RxString error = ''.obs;

  final RxInt selectedTab = 0.obs;
  final RxString directoryFilter = 'all'.obs; // 'all', 'hostel', 'alumni', 'has_dob', 'no_dob'

  static const List<String> hshGroups = [
    'All',
    'Param',
    'Pavitra',
    'Pulkit',
    'Paramanand',
    'Alumni',
  ];

  static const List<String> floorOptions = [
    'All',
    'Ground',
    'Floor 1',
    'Floor 2',
    'Floor 3',
    'Floor 4',
    'Floor 5',
    'Floor 6',
    'Floor 7',
    'Floor 8',
  ];

  static int? floorNumberOf(String option) {
    if (option == 'Ground') return 0;
    return int.tryParse(option.replaceAll(RegExp(r'\D'), ''));
  }

  static const List<String> statusOptions = [
    'All',
    'Active Residents',
    'Alumni / Left',
  ];

  static const List<String> sortOptions = [
    'Default (Hostel First)',
    'Name (A-Z)',
    'Name (Z-A)',
    'Room (Low-High)',
    'Room (High-Low)',
    'Floor (Low-High)',
    'Floor (High-Low)',
  ];

  // Filters & Sorting state
  final RxString selectedGroup = 'All'.obs;
  final RxString selectedFloor = 'All'.obs;
  final RxString selectedStatus = 'All'.obs; // 'All', 'Active Residents', 'Alumni / Left'
  final RxString selectedSort = 'Default (Hostel First)'.obs;

  final RxBool onlyWithDob = false.obs;
  final RxBool onlyWithoutDob = false.obs;
  final RxBool onlyWithWhatsApp = false.obs;
  final RxBool onlyWithParents = false.obs;
  final RxBool onlyWithPhone = false.obs;

  int get activeFilterCount {
    int count = 0;
    if (selectedGroup.value != 'All') count++;
    if (selectedFloor.value != 'All') count++;
    if (selectedStatus.value != 'All') count++;
    if (directoryFilter.value != 'all') count++;
    if (onlyWithDob.value) count++;
    if (onlyWithoutDob.value) count++;
    if (onlyWithWhatsApp.value) count++;
    if (onlyWithParents.value) count++;
    if (onlyWithPhone.value) count++;
    if (selectedSort.value != 'Default (Hostel First)') count++;
    return count;
  }

  void selectGroup(String group) {
    if (isLeader.value) return; // Group is locked to leader's assigned group
    if (selectedGroup.value == group) {
      selectedGroup.value = 'All';
    } else {
      selectedGroup.value = group;
    }
  }

  void selectFloor(String floor) {
    if (selectedFloor.value == floor) {
      selectedFloor.value = 'All';
    } else {
      selectedFloor.value = floor;
    }
  }

  void selectStatus(String status) {
    if (selectedStatus.value == status) {
      selectedStatus.value = 'All';
      if (directoryFilter.value == 'hostel' || directoryFilter.value == 'alumni') {
        directoryFilter.value = 'all';
      }
    } else {
      selectedStatus.value = status;
      if (status == 'Active Residents') {
        directoryFilter.value = 'hostel';
      } else if (status == 'Alumni / Left') {
        directoryFilter.value = 'alumni';
      }
    }
  }

  void selectSort(String sort) {
    selectedSort.value = sort;
  }

  void toggleOnlyWithDob(bool val) {
    onlyWithDob.value = val;
    if (val) {
      onlyWithoutDob.value = false;
      if (directoryFilter.value == 'no_dob') directoryFilter.value = 'has_dob';
    }
  }

  void toggleOnlyWithoutDob(bool val) {
    onlyWithoutDob.value = val;
    if (val) {
      onlyWithDob.value = false;
      if (directoryFilter.value == 'has_dob') directoryFilter.value = 'no_dob';
    }
  }

  void toggleOnlyWithWhatsApp(bool val) {
    onlyWithWhatsApp.value = val;
  }

  void toggleOnlyWithParents(bool val) {
    onlyWithParents.value = val;
  }

  void toggleOnlyWithPhone(bool val) {
    onlyWithPhone.value = val;
  }

  void resetAllFilters() {
    selectedGroup.value = isLeader.value ? (leaderGroup.value ?? 'All') : 'All';
    selectedFloor.value = 'All';
    selectedStatus.value = 'All';
    directoryFilter.value = 'all';
    onlyWithDob.value = false;
    onlyWithoutDob.value = false;
    onlyWithWhatsApp.value = false;
    onlyWithParents.value = false;
    onlyWithPhone.value = false;
    selectedSort.value = 'Default (Hostel First)';
  }

  List<BirthdayStudentModel> get filteredStudents {
    final list = allStudents.where((s) {
      // 1. Group filter
      if (selectedGroup.value != 'All') {
        final g = (groupFor(s) ?? '').toLowerCase().trim();
        final selG = selectedGroup.value.toLowerCase();
        if (selG == 'alumni') {
          if (!isAlumni(s) && g != 'alumni') return false;
        } else {
          if (g != selG) return false;
        }
      }

      // 2. Floor filter
      if (selectedFloor.value != 'All') {
        final expectedFloor = floorNumberOf(selectedFloor.value);
        final studentFloor = PhonebookStudent.floorOfRoom(s.room);
        if (studentFloor != expectedFloor) return false;
      }

      // 3. Status filter / directoryFilter
      final alumni = isAlumni(s);
      if (selectedStatus.value == 'Active Residents' && alumni) return false;
      if (selectedStatus.value == 'Alumni / Left' && !alumni) return false;

      if (directoryFilter.value == 'hostel' && alumni) return false;
      if (directoryFilter.value == 'alumni' && !alumni) return false;
      if (directoryFilter.value == 'has_dob' && s.dob.trim().isEmpty) return false;
      if (directoryFilter.value == 'no_dob' && s.dob.trim().isNotEmpty) return false;

      // 4. Toggle attributes
      if (onlyWithDob.value && s.dob.trim().isEmpty) return false;
      if (onlyWithoutDob.value && s.dob.trim().isNotEmpty) return false;
      if (onlyWithWhatsApp.value && s.whatsappNumber.trim().isEmpty) return false;
      if (onlyWithParents.value && s.parentPhone.trim().isEmpty) return false;
      if (onlyWithPhone.value && s.phone.trim().isEmpty) return false;

      return true;
    }).toList();

    // 5. Sorting
    switch (selectedSort.value) {
      case 'Name (A-Z)':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'Name (Z-A)':
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'Room (Low-High)':
        list.sort((a, b) {
          final roomA = int.tryParse(a.room.replaceAll(RegExp(r'\D'), ''));
          final roomB = int.tryParse(b.room.replaceAll(RegExp(r'\D'), ''));
          if (roomA != null && roomB != null && roomA != roomB) {
            return roomA.compareTo(roomB);
          }
          return a.room.compareTo(b.room);
        });
        break;
      case 'Room (High-Low)':
        list.sort((a, b) {
          final roomA = int.tryParse(a.room.replaceAll(RegExp(r'\D'), ''));
          final roomB = int.tryParse(b.room.replaceAll(RegExp(r'\D'), ''));
          if (roomA != null && roomB != null && roomA != roomB) {
            return roomB.compareTo(roomA);
          }
          return b.room.compareTo(a.room);
        });
        break;
      case 'Floor (Low-High)':
        list.sort((a, b) {
          final floorA = PhonebookStudent.floorOfRoom(a.room) ?? 99;
          final floorB = PhonebookStudent.floorOfRoom(b.room) ?? 99;
          if (floorA != floorB) return floorA.compareTo(floorB);
          final roomA = int.tryParse(a.room.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final roomB = int.tryParse(b.room.replaceAll(RegExp(r'\D'), '')) ?? 0;
          if (roomA != roomB) return roomA.compareTo(roomB);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case 'Floor (High-Low)':
        list.sort((a, b) {
          final floorA = PhonebookStudent.floorOfRoom(a.room) ?? -1;
          final floorB = PhonebookStudent.floorOfRoom(b.room) ?? -1;
          if (floorA != floorB) return floorB.compareTo(floorA);
          final roomA = int.tryParse(a.room.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final roomB = int.tryParse(b.room.replaceAll(RegExp(r'\D'), '')) ?? 0;
          if (roomA != roomB) return roomA.compareTo(roomB);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case 'Default (Hostel First)':
      default:
        sortStudentsList(list);
        break;
    }

    return list;
  }

  // Template editor & config fields
  /// Body of the template open in the editor (see [editingTemplateId]).
  late TextEditingController templateController;
  late TextEditingController templateNameController;
  late TextEditingController testPhoneController;
  late TextEditingController adminPhoneController;
  late TextEditingController searchController;
  late TextEditingController pairPhoneController;

  final RxString adminPhone = ''.obs;
  final RxString sendTime = '08:00'.obs;
  final RxString targetAudience = 'student_only'.obs;
  final RxBool preferWhatsApp = true.obs;
  final RxBool isAutoEnabled = true.obs;

  // WhatsApp Pairing & Device linking
  final RxString waStatus = 'disconnected'.obs;
  final RxString waQr = ''.obs;
  final RxString pairingCode = ''.obs;

  /// Number the current [pairingCode] was issued for, with country code.
  final RxString pairingNumber = ''.obs;
  final RxBool isPairingLoading = false.obs;
  final RxBool isCheckingStatus = false.obs;
  final RxString connectedPhone = ''.obs;
  Timer? _linkingPollTimer;

  static const _prefKey = 'birthday_sent_date';

  /// Group/status from the phonebook synced on this phone, by bank code. Display only.
  final RxMap<String, PhonebookGroupInfo> _phonebookInfo = <String, PhonebookGroupInfo>{}.obs;

  /// Dispatch logs filter: a `yyyy-MM-dd` date, or null for all dates.
  final RxnString logDateFilter = RxnString();

  /// Logs of days picked by the admin, loaded from `/whatsapp/birthday/logs`.
  /// The dashboard itself only carries the most recent logs.
  final RxList<BirthdayLogModel> olderLogs = <BirthdayLogModel>[].obs;

  /// Days fetched with [loadLogsForDate], including days with no wishes.
  final RxSet<String> loadedLogDates = <String>{}.obs;
  final RxBool isLoadingLogs = false.obs;

  // Template library: several templates per audience, one active per audience.
  // Until hsh_api stores `templates`, the library is also cached on this device.
  static const _templatesCacheKey = 'birthday_templates_v1';

  /// Father / mother templates kept on this phone while hsh_api doesn't store
  /// them (see [BirthdayConfigModel.supportsParentBirthdays]).
  static const _parentTemplatesCacheKey = 'birthday_parent_templates_v1';

  /// Parents (father / mother) whose own birthday is today / tomorrow, from
  /// the phonebook synced on this phone. Wished from this phone's WhatsApp.
  final RxList<ParentBirthday> parentBirthdaysToday = <ParentBirthday>[].obs;
  final RxList<ParentBirthday> parentBirthdaysTomorrow = <ParentBirthday>[].obs;

  /// False while the synced phonebook is empty on this phone (nothing to read).
  final RxBool hasPhonebookForParents = true.obs;

  /// The lists above came from the server (`todaysParentBirthdays`), which
  /// also means the server bot can wish them (`send-parent-wish`).
  final RxBool parentBirthdaysFromServer = false.obs;

  /// "Also wish parents on their own birthday" in Send All and the daily run.
  final RxBool includeParentBirthdays = false.obs;

  /// Parents with a bot send in flight ([ParentBirthday.key]).
  final RxSet<String> sendingParentKeys = <String>{}.obs;
  final RxList<BirthdayTemplate> templates = <BirthdayTemplate>[].obs;
  final RxMap<String, String> activeTemplateIds = <String, String>{}.obs;
  final RxString editingAudience = BirthdayAudience.student.obs;
  final RxnString editingTemplateId = RxnString();
  bool _loadingEditor = false;
  String _savedTemplatesSnapshot = '';

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<SessionStore>()) {
      final session = Get.find<SessionStore>().currentSession;
      if (session != null) {
        if (session.role == UserRole.leader || Get.find<SessionStore>().isLeader) {
          isLeader.value = true;
          final grp = session.studentProfile?.groupName;
          if (grp != null && grp.isNotEmpty) {
            leaderGroup.value = grp;
          }
        }
      }
    }

    if (isLeader.value && leaderGroup.value != null && leaderGroup.value!.isNotEmpty) {
      selectedGroup.value = leaderGroup.value!;
    }

    templateController = TextEditingController()..addListener(_onEditorChanged);
    templateNameController = TextEditingController()..addListener(_onEditorChanged);
    testPhoneController = TextEditingController();
    adminPhoneController = TextEditingController()
      ..addListener(() => adminPhone.value = adminPhoneController.text);
    searchController = TextEditingController();
    pairPhoneController = TextEditingController();

    if (isLeader.value) {
      _loadLeaderTemplate();
    }

    _checkIfAlreadySentToday();
    _loadPhonebookInfo();
    loadDashboard();
    if (!isLeader.value) {
      fetchWhatsAppStatus();
    }
  }

  Future<void> _checkIfAlreadySentToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_prefKey);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (savedDate == todayStr) {
      hasSentToday.value = true;
    }
  }

  @override
  void onClose() {
    stopLinkingPolling();
    leaderTemplateController.dispose();
    templateController.dispose();
    templateNameController.dispose();
    testPhoneController.dispose();
    adminPhoneController.dispose();
    searchController.dispose();
    pairPhoneController.dispose();
    super.onClose();
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    error.value = '';
    try {
      final grp = isLeader.value ? leaderGroup.value : null;
      final data = await _repository.fetchDashboard(group: grp);

      // Ensure celebrants are stably sorted: active hostel students first, then alumni
      final sortedTodays = [...data.todaysBirthdays];
      sortStudentsList(sortedTodays);
      final sortedTomorrows = [...data.tomorrowsBirthdays];
      sortStudentsList(sortedTomorrows);

      final isCurrentLeader = data.isLeader || (Get.isRegistered<SessionStore>() && (Get.find<SessionStore>().currentSession?.role == UserRole.leader));
      isLeader.value = isCurrentLeader;
      leaderGroup.value = data.leaderGroup;
      if (isCurrentLeader && data.leaderGroup != null && data.leaderGroup!.isNotEmpty) {
        selectedGroup.value = data.leaderGroup!;
      }

      dashboard.value = BirthdayDashboardData(
        config: data.config,
        todaysBirthdays: sortedTodays,
        tomorrowsBirthdays: sortedTomorrows,
        recentLogs: data.recentLogs,
        isWhatsAppConnected: data.isWhatsAppConnected,
        senderPhone: data.senderPhone,
        isLeader: isCurrentLeader,
        leaderGroup: data.leaderGroup,
        leaderTemplate: data.leaderTemplate,
      );

      if (data.leaderTemplate != null && data.leaderTemplate!.trim().isNotEmpty) {
        leaderTemplate.value = data.leaderTemplate!;
        leaderTemplateController.text = data.leaderTemplate!;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('leader_birthday_wish_template', data.leaderTemplate!);
      } else if (leaderTemplate.value.isEmpty && isCurrentLeader) {
        await _loadLeaderTemplate();
      }

      // Sync form fields
      isAutoEnabled.value = data.config.isEnabled;
      sendTime.value = data.config.sendTime;
      targetAudience.value = data.config.targetAudience;
      preferWhatsApp.value = data.config.preferWhatsAppNumber;
      await _loadTemplates(data.config);
      includeParentBirthdays.value = data.config.includeParentBirthdays;
      _applyParentBirthdays(data);
      adminPhoneController.text = data.config.adminNotificationPhone ?? '';
      adminPhone.value = adminPhoneController.text;

      // Sync WA connection state
      if (data.senderPhone != null && data.senderPhone!.isNotEmpty) {
        connectedPhone.value = data.senderPhone!;
        waStatus.value = 'open';
      } else if (!data.isWhatsAppConnected) {
        connectedPhone.value = '';
        waStatus.value = 'disconnected';
      }

      // If none of today's celebrants have actually been sent according to the backend,
      // reset hasSentToday so the user is never locked out with a disabled button.
      final todays = sortedTodays;
      if (todays.isNotEmpty && todays.every((s) => !s.alreadySentToday)) {
        hasSentToday.value = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefKey);
      } else if (todays.isNotEmpty && todays.every((s) => s.alreadySentToday)) {
        hasSentToday.value = true;
      }
    } catch (e) {
      debugPrint('[AdminBirthdayController] loadDashboard error: $e');
      error.value = 'Failed to load birthday dashboard. Pull down to retry.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Group/status per bank code from the phonebook on this phone. A phone that has
  /// never synced the directory syncs it once here, so cards show groups even when
  /// the API sends no `groupName`.
  Future<void> _loadPhonebookInfo() async {
    try {
      var info = await PhonebookDatabaseService.instance.groupInfoByBankCode();
      if (info.isEmpty && !isLeader.value) {
        final result = await PhonebookSyncService.instance.syncDirectory();
        if (result.success) {
          info = await PhonebookDatabaseService.instance.groupInfoByBankCode();
        }
      }
      _phonebookInfo.assignAll(info);

      // Re-sort celebrants and manual directory lists with updated phonebook statuses
      if (dashboard.value != null) {
        final current = dashboard.value!;
        final sortedTodays = [...current.todaysBirthdays];
        sortStudentsList(sortedTodays);
        final sortedTomorrows = [...current.tomorrowsBirthdays];
        sortStudentsList(sortedTomorrows);
        dashboard.value = BirthdayDashboardData(
          config: current.config,
          todaysBirthdays: sortedTodays,
          tomorrowsBirthdays: sortedTomorrows,
          recentLogs: current.recentLogs,
          isWhatsAppConnected: current.isWhatsAppConnected,
          senderPhone: current.senderPhone,
        );
      }
      if (allStudents.isNotEmpty) {
        final sorted = [...allStudents];
        sortStudentsList(sorted);
        allStudents.assignAll(sorted);
      }
    } catch (e) {
      debugPrint('[AdminBirthdayController] phonebook lookup unavailable: $e');
    }
  }

  PhonebookGroupInfo? _phonebookInfoFor(BirthdayStudentModel s) =>
      _phonebookInfo[PhonebookDatabaseService.normalizeBankCode(s.studentCode)];

  String? groupFor(BirthdayStudentModel s) => groupFrom(s, _phonebookInfoFor(s));

  bool isAlumni(BirthdayStudentModel s) => alumniFrom(s, _phonebookInfoFor(s));

  /// Stable comparator that orders:
  /// 1. Active hostel students first, Alumni students afterwards
  /// 2. Students with a known birthday date (DOB) first, without DOB afterwards
  /// 3. Room-wise (natural numerical order) for hostel students
  /// 4. Alphabetical by name
  int compareBirthdayStudents(BirthdayStudentModel a, BirthdayStudentModel b) {
    final aAlumni = isAlumni(a);
    final bAlumni = isAlumni(b);
    if (aAlumni != bAlumni) {
      return aAlumni ? 1 : -1; // Active hostel student first, Alumni afterwards
    }
    final aHasDob = a.dob.trim().isNotEmpty;
    final bHasDob = b.dob.trim().isNotEmpty;
    if (aHasDob != bHasDob) {
      return aHasDob ? -1 : 1; // Known birthday date first
    }
    if (!aAlumni) {
      final aRoomDigits = a.room.replaceAll(RegExp(r'\D'), '');
      final bRoomDigits = b.room.replaceAll(RegExp(r'\D'), '');
      final aRoomNum = int.tryParse(aRoomDigits);
      final bRoomNum = int.tryParse(bRoomDigits);
      if (aRoomNum != null && bRoomNum != null && aRoomNum != bRoomNum) {
        return aRoomNum.compareTo(bRoomNum);
      }
      final roomComp = a.room.compareTo(b.room);
      if (roomComp != 0) return roomComp;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void sortStudentsList(List<BirthdayStudentModel> list) {
    list.sort(compareBirthdayStudents);
  }

  /// Group for a birthday card: the API's value, else the synced phonebook's.
  static String? groupFrom(BirthdayStudentModel s, PhonebookGroupInfo? phonebook) {
    final fromApi = s.groupName?.trim() ?? '';
    if (fromApi.isNotEmpty) return fromApi;
    final fromPhonebook = phonebook?.group?.trim() ?? '';
    return fromPhonebook.isEmpty ? null : fromPhonebook;
  }

  static bool alumniFrom(BirthdayStudentModel s, PhonebookGroupInfo? phonebook) =>
      s.isAlumni || BirthdayStudentModel.statusMeansAlumni(phonebook?.status);

  // --- Dispatch logs by date ---

  /// IST calendar day (`yyyy-MM-dd`) a log belongs to: its wish date, else when it was sent.
  static String logDateKey(BirthdayLogModel log) {
    if (log.wishDate.isNotEmpty) return log.wishDate;
    final sentAt = DateTime.tryParse(log.sentAt);
    if (sentAt == null) return '';
    return DateFormat('yyyy-MM-dd').format(DateFormatting.utcToIst(sentAt));
  }

  /// Logs grouped by [logDateKey], newest date first (undated logs last).
  static List<({String date, List<BirthdayLogModel> logs})> groupLogsByDate(List<BirthdayLogModel> logs) {
    final byDate = <String, List<BirthdayLogModel>>{};
    for (final log in logs) {
      byDate.putIfAbsent(logDateKey(log), () => []).add(log);
    }
    final dates = byDate.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return b.compareTo(a);
      });
    return [for (final d in dates) (date: d, logs: byDate[d]!)];
  }

  /// "Today", "Yesterday", or "Thu, 23 Oct 2026" for a `yyyy-MM-dd` key.
  static String logDateLabel(String date, {DateTime? now}) {
    final day = DateTime.tryParse(date);
    if (day == null) return 'Unknown date';
    final today = DateFormatting.utcToIst((now ?? DateTime.now()).toUtc());
    final todayDate = DateTime(today.year, today.month, today.day);
    final diff = todayDate.difference(DateTime(day.year, day.month, day.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, dd MMM yyyy').format(day);
  }

  /// The dashboard's recent logs plus the days loaded on demand.
  List<BirthdayLogModel> get allLogs => mergeLogs(dashboard.value?.recentLogs ?? const [], olderLogs);

  /// [recent] followed by [more], dropping logs already in the list (same id).
  static List<BirthdayLogModel> mergeLogs(List<BirthdayLogModel> recent, List<BirthdayLogModel> more) {
    final seen = <int>{};
    return [
      for (final log in [...recent, ...more])
        if (seen.add(log.id)) log,
    ];
  }

  /// Loads every wish logged for [date] (`yyyy-MM-dd`) and filters the logs to that day.
  Future<void> loadLogsForDate(String date) async {
    isLoadingLogs.value = true;
    try {
      final logs = await _repository.fetchLogs(from: date);
      olderLogs
        ..removeWhere((l) => logDateKey(l) == date)
        ..addAll(logs);
      loadedLogDates.add(date);
      logDateFilter.value = date;
    } catch (e) {
      AppSnackbar.error('Logs Unavailable', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoadingLogs.value = false;
    }
  }

  /// Short label for the date filter chips ("Today", "Yesterday", "23 Oct").
  static String logDateChipLabel(String date, {DateTime? now}) {
    final label = logDateLabel(date, now: now);
    if (label == 'Today' || label == 'Yesterday' || label == 'Unknown date') return label;
    return DateFormat('dd MMM').format(DateTime.parse(date));
  }

  /// True when a WhatsApp device session is confirmed online
  bool get isWhatsAppLinked =>
      (dashboard.value?.isWhatsAppConnected ?? false) || connectedPhone.isNotEmpty;

  Future<void> fetchWhatsAppStatus({bool showLoading = true}) async {
    if (showLoading) isCheckingStatus.value = true;
    try {
      final res = await _repository.getWhatsAppStatus();
      if (res.isNotEmpty) {
        final newStatus = res['status']?.toString() ?? 'disconnected';
        waStatus.value = newStatus;
        final newQr = res['qr']?.toString() ?? '';
        if (newQr.isNotEmpty) {
          waQr.value = newQr;
        }
        final user = res['user'];
        if (user is Map && user['phone'] != null) {
          final phone = user['phone'].toString();
          if (connectedPhone.value != phone) {
            connectedPhone.value = phone;
            stopLinkingPolling();
            AppSnackbar.success('WhatsApp Connected!', 'Session active as +$phone');
            loadDashboard();
          }
        } else {
          if (newStatus == 'disconnected' && connectedPhone.isNotEmpty) {
            connectedPhone.value = '';
          }
        }
      }
    } catch (e) {
      debugPrint('[AdminBirthdayController] fetchWhatsAppStatus error: $e');
    } finally {
      if (showLoading) isCheckingStatus.value = false;
    }
  }

  /// Reconnect / trigger QR code emission from backend and update status
  Future<void> loadQrCode() async {
    // /whatsapp/connect restarts the session, which cancels any pairing code.
    pairingCode.value = '';
    pairingNumber.value = '';
    isCheckingStatus.value = true;
    try {
      await _repository.connectWhatsApp();
      await fetchWhatsAppStatus(showLoading: false);
    } catch (e) {
      debugPrint('[AdminBirthdayController] loadQrCode error: $e');
      await fetchWhatsAppStatus(showLoading: false);
    } finally {
      isCheckingStatus.value = false;
    }
  }

  /// Start polling WhatsApp connection status every 3.5 seconds while linking sheet is open
  void startLinkingPolling() {
    _linkingPollTimer?.cancel();
    fetchWhatsAppStatus(showLoading: true);
    _linkingPollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (connectedPhone.isNotEmpty) {
        stopLinkingPolling();
        return;
      }
      await fetchWhatsAppStatus(showLoading: false);
    });
  }

  /// Stop polling WhatsApp connection status
  void stopLinkingPolling() {
    _linkingPollTimer?.cancel();
    _linkingPollTimer = null;
  }

  /// Digits with country code, as WhatsApp's pairing API needs ("919876543210").
  /// A bare 10-digit number is treated as Indian (91). Null if it can't be a phone number.
  static String? normalizeWhatsAppNumber(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length == 10) digits = '91$digits';
    if (digits.length < 11 || digits.length > 15) return null;
    return digits;
  }

  Future<void> requestPairingCode() async {
    // Without the country code WhatsApp issues the code for a different number:
    // no "Enter code" notification arrives and typing the code fails.
    final phone = normalizeWhatsAppNumber(pairPhoneController.text);
    if (phone == null) {
      AppSnackbar.warning('Invalid Number', 'Enter the WhatsApp number on this phone, e.g. 98765 43210.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    isPairingLoading.value = true;
    pairingCode.value = '';
    pairingNumber.value = '';
    waQr.value = ''; // Clear any cached QR — QR mode and pairing-code mode are
                    // mutually exclusive in Baileys / whatsapp-web.js.
    try {
      // The pairing-code API requires the session to be in a clean / idle state.
      // If a QR session is already pending, disconnect it first so the backend
      // can issue the code without the session state conflicting.
      try {
        await _repository.disconnectWhatsApp();
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (_) {
        // Ignore — session may already be clean (first time linking).
      }

      final code = await _repository.requestPairingCode(phone);
      pairingCode.value = code;
      pairingNumber.value = phone;
      // Copy straight away: on the same phone the next step is pasting it in WhatsApp.
      try {
        await Clipboard.setData(ClipboardData(text: code));
      } catch (_) {}
      AppSnackbar.success('Pairing Code Copied', 'Open WhatsApp and paste it under Linked devices.');
    } catch (e) {
      AppSnackbar.error('Pairing Failed', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isPairingLoading.value = false;
    }
  }

  /// Drops the shown pairing code so the QR option can be used instead.
  void cancelPairingCode() {
    pairingCode.value = '';
    pairingNumber.value = '';
  }

  /// Opens the WhatsApp app. There is no public link straight to Linked devices.
  /// launchUrl is called directly: canLaunchUrl needs the scheme declared in
  /// AndroidManifest `<queries>` / iOS LSApplicationQueriesSchemes and says "no" otherwise.
  Future<void> openWhatsAppApp() async {
    for (final url in ['whatsapp://', 'https://wa.me/']) {
      try {
        if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    AppSnackbar.warning('Could Not Open WhatsApp', 'Open WhatsApp yourself, then go to Settings → Linked devices.');
  }

  Future<void> disconnectWhatsAppSession() async {
    try {
      await _repository.disconnectWhatsApp();
      pairingCode.value = '';
      pairingNumber.value = '';
      waStatus.value = 'disconnected';
      connectedPhone.value = '';
      AppSnackbar.success('Disconnected', 'WhatsApp device session unlinked.');
      await loadDashboard();
      await fetchWhatsAppStatus();
    } catch (e) {
      AppSnackbar.error('Disconnect Failed', e.toString());
    }
  }

  Future<void> toggleAutomation(bool enabled) async {
    if (isLeader.value) {
      AppSnackbar.warning('Access Denied', 'Global automation settings can only be modified by hostel administrators.');
      return;
    }
    final current = dashboard.value?.config;
    if (current == null) return;
    isAutoEnabled.value = enabled;

    try {
      final updated = await _repository.saveConfig(current.copyWith(isEnabled: enabled));
      dashboard.value = BirthdayDashboardData(
        config: updated,
        todaysBirthdays: dashboard.value!.todaysBirthdays,
        tomorrowsBirthdays: dashboard.value!.tomorrowsBirthdays,
        recentLogs: dashboard.value!.recentLogs,
        isWhatsAppConnected: dashboard.value!.isWhatsAppConnected,
        senderPhone: dashboard.value!.senderPhone,
      );
      AppSnackbar.success(
        'Automation ${enabled ? "Enabled" : "Disabled"}',
        enabled
            ? 'Birthday wishes will be sent daily at ${updated.sendTime} IST.'
            : 'Automated daily sending has been paused.',
      );
    } catch (e) {
      isAutoEnabled.value = !enabled; // Rollback
      AppSnackbar.error('Failed to update', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> saveSettings() async {
    if (isLeader.value) {
      AppSnackbar.warning('Access Denied', 'Global automation settings can only be modified by hostel administrators.');
      return;
    }
    // Close the keyboard (template / admin phone field) when saving.
    FocusManager.instance.primaryFocus?.unfocus();
    final current = dashboard.value?.config;
    if (current == null) return;

    final problem = _templateProblem();
    if (problem != null) {
      AppSnackbar.warning('Check Templates', problem);
      return;
    }

    isSaving.value = true;
    try {
      final updated = await _repository.saveConfig(
        _withTemplates(
          current.copyWith(
            isEnabled: isAutoEnabled.value,
            sendTime: sendTime.value,
            targetAudience: targetAudience.value,
            preferWhatsAppNumber: preferWhatsApp.value,
            adminNotificationPhone: adminPhoneController.text.trim().isEmpty ? null : adminPhoneController.text.trim(),
            includeParentBirthdays: includeParentBirthdays.value,
          ),
        ),
      );
      await _markTemplatesSaved();
      dashboard.value = BirthdayDashboardData(
        config: updated,
        todaysBirthdays: dashboard.value!.todaysBirthdays,
        tomorrowsBirthdays: dashboard.value!.tomorrowsBirthdays,
        recentLogs: dashboard.value!.recentLogs,
        isWhatsAppConnected: dashboard.value!.isWhatsAppConnected,
        senderPhone: dashboard.value!.senderPhone,
      );
      AppSnackbar.success('Settings Saved', 'Birthday configuration updated successfully.');
    } catch (e) {
      AppSnackbar.error('Save Failed', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> triggerAllToday({VoidCallback? onNeedLinkDevice}) async {
    // 1. Ensure there are celebrants to send to (parents too, when the run includes them)
    final parentsToWish = parentBirthdaysFromServer.value && includeParentBirthdays.value
        ? parentBirthdaysToday.where((p) => !p.alreadySent).length
        : 0;
    final countToTrigger = (dashboard.value?.todaysBirthdays.length ?? 0) + parentsToWish;
    if (countToTrigger == 0) {
      AppSnackbar.info('No Celebrants', 'There are no birthdays registered for today.');
      return;
    }

    // 2. Which WhatsApp number to send from (asked only when several are linked)
    final from = await pickSendFromAccount(purpose: 'birthday');
    if (from == null) return;
    if (from.legacy && !isWhatsAppLinked) {
      AppSnackbar.warning(
        'WhatsApp Not Connected',
        'Please link your WhatsApp device first before sending birthday wishes.',
      );
      if (onNeedLinkDevice != null) {
        onNeedLinkDevice();
      }
      return;
    }

    isTriggering.value = true;
    try {
      final result = await _repository.triggerWishes(accountId: from.accountId);
      final count = result['count'] is num ? (result['count'] as num).toInt() : 0;

      if (count > 0) {
        hasSentToday.value = true;
        // Persist today's date so button stays disabled across navigation ONLY when wishes actually sent
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await prefs.setString(_prefKey, todayStr);
        AppSnackbar.success(
          'Wishes Dispatched',
          'Successfully dispatched birthday greetings to $count celebrant(s).',
        );
      } else {
        // Dispatched to 0 — do NOT disable the button or mark as sent
        final msg = result['message']?.toString();
        if (msg != null && msg.toLowerCase().contains('whatsapp')) {
          AppSnackbar.warning(
            'WhatsApp Connection Required',
            msg,
          );
          if (onNeedLinkDevice != null) {
            onNeedLinkDevice();
          }
        } else {
          AppSnackbar.warning(
            'No Wishes Dispatched',
            '0 greetings were sent. Please verify that your WhatsApp device session is active and linked.',
          );
        }
      }
      await loadDashboard(); // Reload logs & status
    } catch (e) {
      AppSnackbar.error('Trigger Failed', e.toString());
    } finally {
      isTriggering.value = false;
    }
  }

  Future<void> sendTestWish({VoidCallback? onNeedLinkDevice}) async {
    final phone = testPhoneController.text.trim();
    if (phone.length < 10) {
      AppSnackbar.warning('Invalid Number', 'Please enter a valid 10-digit mobile number.');
      return;
    }

    final from = await pickSendFromAccount(purpose: 'birthday');
    if (from == null) return;
    if (from.legacy && !isWhatsAppLinked) {
      AppSnackbar.warning(
        'WhatsApp Not Connected',
        'Please link your WhatsApp device first before sending a test wish.',
      );
      if (onNeedLinkDevice != null) {
        onNeedLinkDevice();
      }
      return;
    }

    isTriggering.value = true;
    try {
      final res = await _repository.triggerWishes(testPhone: phone, accountId: from.accountId);
      if (res['success'] == false) {
        AppSnackbar.warning(
          'Test Wish Failed',
          res['message']?.toString() ?? 'Failed to send test wish.',
        );
      } else {
        AppSnackbar.success('Test Wish Sent', 'Delivered test birthday greeting to $phone.');
      }
    } catch (e) {
      AppSnackbar.error('Test Wish Failed', e.toString());
    } finally {
      isTriggering.value = false;
    }
  }

  Future<void> fetchStudents({String? query}) async {
    isLoadingStudents.value = true;
    try {
      final effectiveGroup = isLeader.value
          ? leaderGroup.value
          : (selectedGroup.value != 'All' ? selectedGroup.value : null);
      final students = await _repository.fetchAllStudents(
        search: query,
        group: effectiveGroup,
      );
      sortStudentsList(students);
      allStudents.assignAll(students);
    } catch (e) {
      debugPrint('[AdminBirthdayController] fetchStudents error: $e');
    } finally {
      isLoadingStudents.value = false;
    }
  }

  // --- Template library ---

  static const defaultStudentTemplate =
      'Dear {student_name}, 🎂🎉 Wishing you a very Happy Birthday from Hari Saurabh Hostel family! May your special day bring you immense joy, good health, and success! 🌟✨ - HSH Warden Team';
  static const defaultParentTemplate =
      'Dear Parent, 🎂 Hari Saurabh Hostel family wishes {student_name} a very Happy Birthday! May {first_name} be blessed with joy, good health and success. 🌟 - HSH Warden Team';

  static const defaultFatherTemplate =
      'Dear {parent_name}, 🎂 Hari Saurabh Hostel family wishes you a very Happy Birthday! Thank you for being part of our family through {student_name}. Wishing you good health and happiness. 🌟 - HSH Warden Team';
  static const defaultMotherTemplate =
      'Dear {parent_name}, 🎂🌸 Hari Saurabh Hostel family wishes you a very Happy Birthday! Thank you for your blessings on {student_name} and all of us. Wishing you joy and good health. 🌟 - HSH Warden Team';

  static String defaultBodyFor(String audience) => switch (audience) {
        BirthdayAudience.parent => defaultParentTemplate,
        BirthdayAudience.father => defaultFatherTemplate,
        BirthdayAudience.mother => defaultMotherTemplate,
        _ => defaultStudentTemplate,
      };

  static String audienceLabel(String audience) => switch (audience) {
        BirthdayAudience.parent => 'Parent',
        BirthdayAudience.father => 'Father',
        BirthdayAudience.mother => 'Mother',
        _ => 'Student',
      };

  /// Builds the template library from the API config, falling back to the local
  /// [cache] while the API has no `templates` field. Every audience ends up with
  /// at least one template and a valid active id.
  ///
  /// Father / mother templates come from the server only when it stores them
  /// ([BirthdayConfigModel.supportsParentBirthdays]); otherwise from
  /// [parentCache], the copy kept on this phone.
  static ({List<BirthdayTemplate> templates, Map<String, String> active}) resolveTemplates(
    BirthdayConfigModel config,
    Map<String, dynamic>? cache, {
    Map<String, dynamic>? parentCache,
  }) {
    final fromServer = config.templatesFromServer && config.templates.isNotEmpty;
    final templates = <BirthdayTemplate>[];
    final active = <String, String>{};
    if (fromServer) {
      templates.addAll(config.supportsParentBirthdays
          ? config.templates
          : config.templates.where((t) => BirthdayAudience.all.contains(t.audience)));
      if (config.activeStudentTemplateId != null) active[BirthdayAudience.student] = config.activeStudentTemplateId!;
      if (config.activeParentTemplateId != null) active[BirthdayAudience.parent] = config.activeParentTemplateId!;
      if (config.supportsParentBirthdays) {
        if (config.activeFatherTemplateId != null) active[BirthdayAudience.father] = config.activeFatherTemplateId!;
        if (config.activeMotherTemplateId != null) active[BirthdayAudience.mother] = config.activeMotherTemplateId!;
      }
    } else if (cache != null) {
      templates.addAll(BirthdayTemplate.listFromJson(cache['templates']));
      final cachedActive = cache['active'];
      if (cachedActive is Map) {
        cachedActive.forEach((k, v) => active['$k'] = '$v');
      }
    }

    // Father / mother templates kept on this phone fill in what the server lacks.
    // A server that supports them but has none saved yet (just upgraded) still
    // takes the phone's copy, which the next save then uploads.
    final serverHasParents = fromServer &&
        config.supportsParentBirthdays &&
        config.templates.any((t) => BirthdayAudience.parentBirthdays.contains(t.audience));
    if (!serverHasParents && parentCache != null) {
      final known = templates.map((t) => t.id).toSet();
      for (final t in BirthdayTemplate.listFromJson(parentCache['templates'])) {
        if (BirthdayAudience.parentBirthdays.contains(t.audience) && known.add(t.id)) templates.add(t);
      }
      final cachedActive = parentCache['active'];
      if (cachedActive is Map) {
        for (final a in BirthdayAudience.parentBirthdays) {
          if (cachedActive[a] != null) active[a] = '${cachedActive[a]}';
        }
      }
    }

    for (final audience in BirthdayAudience.every) {
      final sentBody = switch (audience) {
        BirthdayAudience.student => config.messageTemplate,
        BirthdayAudience.parent => config.parentMessageTemplate,
        _ => '',
      }
          .trim();
      final forAudience = templates.where((t) => t.audience == audience).toList();

      if (forAudience.isEmpty) {
        final first = BirthdayTemplate(
          id: 'default_$audience',
          name: 'Default ${audienceLabel(audience).toLowerCase()} wish',
          body: sentBody.isNotEmpty ? sentBody : defaultBodyFor(audience),
          audience: audience,
        );
        templates.add(first);
        active[audience] = first.id;
        continue;
      }

      if (!forAudience.any((t) => t.id == active[audience])) {
        active[audience] = forAudience.first.id;
      }

      // The server's stored body is what actually gets sent; if another device changed it,
      // reflect that in the cached active template.
      if (!fromServer && sentBody.isNotEmpty) {
        final i = templates.indexWhere((t) => t.id == active[audience]);
        if (templates[i].body.trim() != sentBody) templates[i] = templates[i].copyWith(body: sentBody);
      }
    }
    return (templates: templates, active: active);
  }

  /// Whether hsh_api stores father / mother templates (else kept on this phone).
  bool get supportsParentBirthdays => dashboard.value?.config.supportsParentBirthdays ?? false;

  List<BirthdayTemplate> templatesFor(String audience) =>
      templates.where((t) => t.audience == audience).toList();

  BirthdayTemplate? _findTemplate(String? id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool isActiveTemplate(BirthdayTemplate t) => activeTemplateIds[t.audience] == t.id;

  /// Body of the active template for [audience], trimmed ('' if none).
  String activeBody(String audience) => _findTemplate(activeTemplateIds[audience])?.body.trim() ?? '';

  bool get hasUnsavedTemplateChanges => _templatesSnapshot() != _savedTemplatesSnapshot;

  /// Returns true if any setting (target audience, send time, admin phone, or templates)
  /// has been modified from the last saved configuration.
  bool get hasUnsavedChanges {
    final config = dashboard.value?.config;
    if (config == null) return false;
    if (targetAudience.value != config.targetAudience) return true;
    if (sendTime.value != config.sendTime) return true;
    final savedAdminPhone = (config.adminNotificationPhone ?? '').trim();
    if (adminPhone.value.trim() != savedAdminPhone) return true;
    if (hasUnsavedTemplateChanges) return true;
    if (config.supportsParentBirthdays && includeParentBirthdays.value != config.includeParentBirthdays) return true;
    return false;
  }

  /// Reverts all settings and templates back to the last saved configuration from the server.
  void discardUnsavedChanges() {
    final config = dashboard.value?.config;
    if (config == null) return;
    targetAudience.value = config.targetAudience;
    sendTime.value = config.sendTime;
    adminPhoneController.text = config.adminNotificationPhone ?? '';
    adminPhone.value = adminPhoneController.text;
    includeParentBirthdays.value = config.includeParentBirthdays;
    _loadTemplates(config);
  }

  void selectTemplateAudience(String audience) {
    editingAudience.value = audience;
    _openEditor(activeTemplateIds[audience]);
  }

  void editTemplate(String id) => _openEditor(id);

  void addTemplate() {
    if (templates.length >= maxTemplates) {
      AppSnackbar.warning('Too Many Templates', 'You can keep up to $maxTemplates templates. Delete one you no longer use.');
      return;
    }
    final audience = editingAudience.value;
    final label = audienceLabel(audience);
    final template = BirthdayTemplate(
      id: 'tpl_${DateTime.now().microsecondsSinceEpoch}',
      name: '$label wish ${templatesFor(audience).length + 1}',
      body: defaultBodyFor(audience),
      audience: audience,
    );
    templates.add(template);
    activeTemplateIds.putIfAbsent(audience, () => template.id);
    _openEditor(template.id);
  }

  void setActiveTemplate(String id) {
    final template = _findTemplate(id);
    if (template == null) return;
    activeTemplateIds[template.audience] = id;
  }

  void deleteTemplate(String id) {
    final template = _findTemplate(id);
    if (template == null) return;
    if (isActiveTemplate(template)) {
      AppSnackbar.warning('Template Is Active', 'Set another template as active before deleting this one.');
      return;
    }
    templates.removeWhere((t) => t.id == id);
    if (editingTemplateId.value == id) _openEditor(activeTemplateIds[template.audience]);
  }

  void _openEditor(String? id) {
    final template = _findTemplate(id);
    editingTemplateId.value = template?.id;
    _loadingEditor = true;
    templateNameController.text = template?.name ?? '';
    templateController.text = template?.body ?? '';
    _loadingEditor = false;
  }

  /// Copies editor text into the template being edited.
  void _onEditorChanged() {
    if (_loadingEditor) return;
    final i = templates.indexWhere((t) => t.id == editingTemplateId.value);
    if (i < 0) return;
    final current = templates[i];
    final name = templateNameController.text;
    final body = templateController.text;
    if (current.name == name && current.body == body) return;
    templates[i] = current.copyWith(name: name, body: body);
  }

  // Limits hsh_api enforces on POST /whatsapp/birthday/config.
  static const maxTemplates = 50;
  static const maxTemplateBodyLength = 4000;
  static const maxTemplateNameLength = 100;

  /// Why the templates can't be saved yet, or null if they can. Mirrors the
  /// checks hsh_api makes, so a save isn't rejected after the fact.
  static String? templateProblem(
    List<BirthdayTemplate> templates,
    Map<String, String> active,
    String targetAudience,
  ) {
    String activeBodyOf(String audience) {
      for (final t in templates) {
        if (t.id == active[audience]) return t.body.trim();
      }
      return '';
    }

    if (activeBodyOf(BirthdayAudience.student).isEmpty) {
      return 'The active student template is empty. Write a message or pick another template.';
    }
    if (targetAudience != 'student_only' && activeBodyOf(BirthdayAudience.parent).isEmpty) {
      return 'The active parent template is empty. Write a message or pick another template.';
    }
    if (templates.length > maxTemplates) {
      return 'You can keep up to $maxTemplates templates. Delete the ones you no longer use.';
    }
    // Drafts may be empty; only their size is limited.
    for (final t in templates) {
      final name = t.name.trim().isEmpty ? 'A template' : '"${t.name.trim()}"';
      if (t.name.length > maxTemplateNameLength) {
        return 'The name $name is too long. Keep it under $maxTemplateNameLength characters.';
      }
      if (t.body.length > maxTemplateBodyLength) {
        return '$name is too long. Keep it under $maxTemplateBodyLength characters.';
      }
    }
    return null;
  }

  String? _templateProblem() => templateProblem(templates, activeTemplateIds, targetAudience.value);

  /// [config] plus the template library. `messageTemplate` stays the active student
  /// body, so an hsh_api without template support keeps working.
  ///
  /// Father / mother templates are sent only when the server stores them; an
  /// older hsh_api never sees them (they stay on this phone).
  BirthdayConfigModel _withTemplates(BirthdayConfigModel config) {
    final withParents = config.supportsParentBirthdays;
    return config.copyWith(
      messageTemplate: activeBody(BirthdayAudience.student),
      parentMessageTemplate: activeBody(BirthdayAudience.parent),
      templates: withParents
          ? templates.toList()
          : templates.where((t) => BirthdayAudience.all.contains(t.audience)).toList(),
      activeStudentTemplateId: activeTemplateIds[BirthdayAudience.student],
      activeParentTemplateId: activeTemplateIds[BirthdayAudience.parent],
      activeFatherTemplateId: withParents ? activeTemplateIds[BirthdayAudience.father] : null,
      activeMotherTemplateId: withParents ? activeTemplateIds[BirthdayAudience.mother] : null,
    );
  }

  String _templatesSnapshot() => jsonEncode({
        'templates': templates.map((t) => t.toJson()).toList(),
        'active': Map<String, String>.of(activeTemplateIds),
      });

  Future<void> _loadTemplates(BirthdayConfigModel config) async {
    Map<String, dynamic>? cache;
    if (!config.templatesFromServer || config.templates.isEmpty) {
      try {
        final raw = (await SharedPreferences.getInstance()).getString(_templatesCacheKey);
        if (raw != null) cache = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (e) {
        debugPrint('[AdminBirthdayController] template cache unreadable: $e');
      }
    }
    Map<String, dynamic>? parentCache;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_parentTemplatesCacheKey);
      if (raw != null) parentCache = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[AdminBirthdayController] parent template cache unreadable: $e');
    }
    final resolved = resolveTemplates(config, cache, parentCache: parentCache);
    templates.assignAll(resolved.templates);
    activeTemplateIds.assignAll(resolved.active);
    await _markTemplatesSaved();
    _openEditor(activeTemplateIds[editingAudience.value]);
  }

  Future<void> _markTemplatesSaved() async {
    _savedTemplatesSnapshot = _templatesSnapshot();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_templatesCacheKey, _savedTemplatesSnapshot);
      await prefs.setString(
        _parentTemplatesCacheKey,
        jsonEncode({
          'templates': templates
              .where((t) => BirthdayAudience.parentBirthdays.contains(t.audience))
              .map((t) => t.toJson())
              .toList(),
          'active': {
            for (final a in BirthdayAudience.parentBirthdays)
              if (activeTemplateIds[a] != null) a: activeTemplateIds[a],
          },
        }),
      );
    } catch (e) {
      debugPrint('[AdminBirthdayController] template cache write failed: $e');
    }
  }

  // --- Parents' own birthdays ---

  /// Uses the server's lists when the API sends them; otherwise reads the
  /// phonebook synced on this phone.
  void _applyParentBirthdays(BirthdayDashboardData data) {
    final today = data.todaysParentBirthdays;
    final tomorrow = data.tomorrowsParentBirthdays;
    if (today != null && tomorrow != null) {
      parentBirthdaysFromServer.value = true;
      parentBirthdaysToday.assignAll(sortParents(today.map(ParentBirthday.fromServer)));
      parentBirthdaysTomorrow.assignAll(sortParents(tomorrow.map(ParentBirthday.fromServer)));
      return;
    }
    parentBirthdaysFromServer.value = false;
    unawaited(loadParentBirthdays());
  }

  /// Fathers first, then by name (same order as the phonebook lists).
  static List<ParentBirthday> sortParents(Iterable<ParentBirthday> list) => list.toList()
    ..sort((a, b) {
      if (a.isFather != b.isFather) return a.isFather ? -1 : 1;
      return a.parentName.toLowerCase().compareTo(b.parentName.toLowerCase());
    });

  /// Whether [p] can be wished by the server bot now: today's server list,
  /// with a student id, not already wished.
  bool canWishParentViaBot(ParentBirthday p) =>
      parentBirthdaysFromServer.value && p.studentIds.isNotEmpty && !p.alreadySent;

  /// Sends the active father / mother template to [p] through the server bot,
  /// from the WhatsApp number the admin picks.
  Future<void> wishParentViaBot(ParentBirthday p) async {
    if (!canWishParentViaBot(p) || sendingParentKeys.contains(p.key)) return;
    final from = await pickSendFromAccount(purpose: 'birthday');
    if (from == null) return;
    if (from.legacy && !isWhatsAppLinked) {
      AppSnackbar.warning('WhatsApp Not Connected', 'Link a WhatsApp number first, then send again.');
      return;
    }
    sendingParentKeys.add(p.key);
    try {
      await _repository.sendParentWish(role: p.role, studentId: p.studentIds.first, accountId: from.accountId);
      _markParentSent(p);
      AppSnackbar.success('Birthday Wish Sent 🎂', 'Sent to ${p.parentName} on WhatsApp.');
    } on ParentAlreadyWishedException catch (e) {
      _markParentSent(p);
      AppSnackbar.info('Already Wished', e.message);
    } catch (e) {
      AppSnackbar.error('Could Not Send', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      sendingParentKeys.remove(p.key);
    }
  }

  void _markParentSent(ParentBirthday p) {
    final i = parentBirthdaysToday.indexWhere((x) => x.key == p.key);
    if (i >= 0) parentBirthdaysToday[i] = parentBirthdaysToday[i].copyWith(alreadySent: true);
  }

  /// Reads father / mother birthdays for today and tomorrow from the synced
  /// phonebook. A leader only sees their own group.
  Future<void> loadParentBirthdays({DateTime? now}) async {
    try {
      final students = await PhonebookDatabaseService.instance.searchStudents();
      hasPhonebookForParents.value = students.isNotEmpty;
      final today = now ?? DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final group = isLeader.value ? leaderGroup.value : null;
      parentBirthdaysToday.assignAll(ParentBirthday.on(students, day, group: group));
      parentBirthdaysTomorrow.assignAll(ParentBirthday.on(students, day.add(const Duration(days: 1)), group: group));
    } catch (e) {
      debugPrint('[AdminBirthdayController] parent birthdays: $e');
    }
  }

  /// [template] for a parent's own birthday. Placeholders: {parent_name}
  /// (full name), {first_name} (the parent's first name), {student_name}
  /// (their child / children), {age} (age they turn), {room}.
  static String fillParentTemplate(String template, ParentBirthday p) {
    final first = p.parentName.trim().split(RegExp(r'\s+')).first;
    final children = p.studentNames.length <= 1
        ? (p.studentNames.isEmpty ? '' : p.studentNames.first)
        : '${p.studentNames.sublist(0, p.studentNames.length - 1).join(', ')} & ${p.studentNames.last}';
    return template
        .replaceAll('{parent_name}', p.parentName)
        .replaceAll('{name}', p.parentName)
        .replaceAll('{first_name}', first)
        .replaceAll('{student_name}', children)
        .replaceAll('{age}', p.turning?.toString() ?? '')
        .replaceAll('{room}', p.room ?? '')
        .replaceAll('{room_number}', p.room ?? '');
  }

  /// Opens this phone's WhatsApp to [p] with the active father / mother template.
  Future<void> wishParentViaWhatsApp(ParentBirthday p) async {
    if (p.phone.replaceAll(RegExp(r'\D'), '').isEmpty) {
      AppSnackbar.warning('No Contact Number', 'No phone number registered for ${p.parentName}.');
      return;
    }
    var body = activeBody(p.role);
    if (body.isEmpty) body = defaultBodyFor(p.role);
    await openWhatsApp(p.phone, customText: fillParentTemplate(body, p));
  }



  void insertVariableTag(String tag) {
    final text = templateController.text;
    final selection = templateController.selection;
    if (selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      templateController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      templateController.text = text + tag;
    }
  }

  String defaultLeaderTemplate() {
    final group = leaderGroup.value;
    final groupPart = (group != null && group.isNotEmpty) ? '$group Group Leader' : 'Hostel Leader';
    final leaderName = Get.isRegistered<SessionStore>()
        ? (Get.find<SessionStore>().currentSession?.name ?? '')
        : '';
    final sign = leaderName.isNotEmpty ? '- $leaderName ($groupPart)' : '- $groupPart';

    return 'Jay Swaminarayan {first_name}!\n\n'
        'Wishing you a very Happy Birthday! 🎉🎂\n'
        'May Maharaj and Swami bless you with good health, happiness, and great success in your studies! 🌟✨\n\n'
        '$sign';
  }

  Future<void> _loadLeaderTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('leader_birthday_wish_template');
    if (cached != null && cached.trim().isNotEmpty) {
      leaderTemplate.value = cached;
      leaderTemplateController.text = cached;
    } else {
      final def = defaultLeaderTemplate();
      leaderTemplate.value = def;
      leaderTemplateController.text = def;
    }
  }

  Future<void> saveLeaderTemplate() async {
    final text = leaderTemplateController.text.trim();
    if (text.isEmpty) {
      AppSnackbar.warning('Empty Template', 'Please enter a message for your birthday wish template.');
      return;
    }
    isSaving.value = true;
    try {
      leaderTemplate.value = text;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('leader_birthday_wish_template', text);
      await _repository.saveLeaderTemplate(text);
      AppSnackbar.success('Template Saved', 'Your custom group birthday template has been saved.');
    } catch (e) {
      AppSnackbar.info('Saved Locally', 'Template saved on device.');
    } finally {
      isSaving.value = false;
    }
  }

  void resetLeaderTemplateToDefault() {
    final def = defaultLeaderTemplate();
    leaderTemplateController.text = def;
    leaderTemplate.value = def;
  }

  void insertLeaderPlaceholder(String tag) {
    final text = leaderTemplateController.text;
    final selection = leaderTemplateController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      leaderTemplateController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      leaderTemplateController.text = text + tag;
    }
  }

  /// Formats the greeting message for a student based on current template settings
  String formatWishMessage(BirthdayStudentModel student) {
    String template;
    if (isLeader.value) {
      if (leaderTemplate.value.trim().isNotEmpty) {
        template = leaderTemplate.value;
      } else {
        template = defaultLeaderTemplate();
      }
    } else {
      // Manual sends go to the student, so they use the active student template.
      template = activeBody(BirthdayAudience.student);
      if (template.isEmpty) {
        template = dashboard.value?.config.messageTemplate ?? '';
      }
      if (template.isEmpty) {
        template = 'Hare Krishna {first_name}! Wishing you a very Happy Birthday from Hari Saurabh Hostel!';
      }
    }

    final fullName = student.name.trim();
    final firstName = fullName.isNotEmpty ? fullName.split(' ').first : 'Student';
    final room = (student.room.isEmpty || student.room == 'N/A') ? '' : student.room;
    final code = student.studentCode;

    var formatted = fillTemplate(template, firstName: firstName, fullName: fullName, room: room, code: code);
    if (isLeader.value && formatted.contains('- HSH Warden Team')) {
      final group = leaderGroup.value;
      final sig = (group != null && group.isNotEmpty) ? '- $group Group Leader' : '- Hostel Leader';
      formatted = formatted.replaceAll('- HSH Warden Team', sig);
    }
    return formatted;
  }

  /// Replaces the template placeholders. Shared by real sends and the Template Studio preview.
  static String fillTemplate(
    String template, {
    required String firstName,
    required String fullName,
    required String room,
    required String code,
  }) {
    return template
        .replaceAll('{first_name}', firstName)
        .replaceAll('{student_name}', fullName)
        .replaceAll('{name}', fullName)
        .replaceAll('{room}', room)
        .replaceAll('{room_number}', room)
        .replaceAll('{student_code}', code)
        .replaceAll('{code}', code);
  }

  /// Sends a personalized birthday wish to a specific student via WhatsApp based on template setting
  Future<void> sendWishToStudent(BirthdayStudentModel student) async {
    final phone = student.whatsappNumber.isNotEmpty ? student.whatsappNumber : student.phone;
    if (phone.trim().isEmpty) {
      AppSnackbar.warning('No Contact Number', 'No phone number registered for ${student.name}.');
      return;
    }
    final message = formatWishMessage(student);
    await openWhatsApp(phone, customText: message);
  }

  Future<void> openWhatsApp(String phone, {String? customText}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final fullNumber = cleanPhone.startsWith('91') && cleanPhone.length > 10
        ? cleanPhone
        : cleanPhone.length == 10
            ? '91$cleanPhone'
            : cleanPhone;

    final String messageText;
    if (customText != null && customText.isNotEmpty) {
      messageText = customText;
    } else {
      String template = activeBody(BirthdayAudience.student);
      if (template.isEmpty) {
        template = dashboard.value?.config.messageTemplate ?? '';
      }
      if (template.isEmpty) {
        template = 'Hare Krishna! Wishing you a very Happy Birthday from Hari Saurabh Hostel!';
      }
      messageText = template
          .replaceAll('{first_name}', 'Student')
          .replaceAll('{student_name}', 'Student')
          .replaceAll('{name}', 'Student')
          .replaceAll('{room}', '')
          .replaceAll('{room_number}', '')
          .replaceAll('{student_code}', '')
          .replaceAll('{code}', '');
    }

    final text = Uri.encodeComponent(messageText);
    final uri = Uri.parse('https://wa.me/$fullNumber?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      AppSnackbar.warning('WhatsApp not installed', 'Could not launch WhatsApp.');
    }
  }

  Future<void> callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
