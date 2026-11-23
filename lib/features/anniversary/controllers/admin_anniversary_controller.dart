import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/anniversary/anniversary_models.dart';
import '../../../core/models/birthday/birthday_models.dart';
import '../../../core/network/repository/anniversary/anniversary_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/apple_search_utils.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../../whatsapp_accounts/widgets/send_from_sheet.dart';

class AdminAnniversaryController extends GetxController {
  final AnniversaryRepository _repository = AnniversaryRepository();

  final Rxn<AnniversaryDashboardData> dashboard = Rxn<AnniversaryDashboardData>();
  final RxList<AnniversaryStudentRecord> allStudents = <AnniversaryStudentRecord>[].obs;
  final RxList<BirthdayLogModel> logs = <BirthdayLogModel>[].obs;

  final RxBool isLeader = (Get.isRegistered<SessionStore>() && Get.find<SessionStore>().isLeader).obs;
  final RxnString leaderGroup = RxnString(
    Get.isRegistered<SessionStore>()
        ? Get.find<SessionStore>().currentSession?.studentProfile?.groupName
        : null,
  );

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isTriggering = false.obs;
  final RxBool isLoadingStudents = false.obs;
  final RxBool isLoadingLogs = false.obs;
  final RxString error = ''.obs;

  final RxInt selectedTab = 0.obs; // 0: Today, 1: Tomorrow, 2: Template Studio, 3: Directory, 4: Logs

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
    'Anniversary Date (Jan-Dec)',
  ];

  // Filters & Sorting state
  final RxString selectedGroup = 'All'.obs;
  final RxString selectedFloor = 'All'.obs;
  final RxString selectedStatus = 'All'.obs;
  final RxString selectedSort = 'Default (Hostel First)'.obs;
  final RxString directoryFilter = 'all'.obs;

  final RxBool onlyWithAnniversaryDate = false.obs;
  final RxBool onlyWithoutAnniversaryDate = false.obs;
  final RxBool onlyWithFatherPhone = false.obs;
  final RxBool onlyWithMotherPhone = false.obs;
  final RxBool onlyWithBothPhones = false.obs;

  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  // Settings & Template Controllers
  /// Body of the template open in the editor (see [editingTemplateId]).
  final TextEditingController templateController = TextEditingController();

  /// Name of the template open in the editor.
  final TextEditingController templateNameController = TextEditingController();
  final FocusNode templateFocus = FocusNode();
  final TextEditingController sendTimeController = TextEditingController();

  // Template library (saved with the settings, like the birthday Template Studio).
  static const maxTemplates = 50;
  static const maxTemplateBodyLength = 4000;
  static const maxTemplateNameLength = 100;
  final RxList<AnniversaryTemplate> templates = <AnniversaryTemplate>[].obs;
  final RxnString activeTemplateId = RxnString();
  final RxnString editingTemplateId = RxnString();
  bool _loadingEditor = false;
  String _savedTemplatesSnapshot = '';
  final RxBool isAnniversaryEnabled = true.obs;
  final RxString previewRecipientType = 'both'.obs; // 'both', 'father', 'mother'
  final TextEditingController testPhoneController = TextEditingController();

  // Custom wishing desk inputs
  final TextEditingController customWishPhoneController = TextEditingController();
  final TextEditingController customWishMessageController = TextEditingController();
  final RxString customWishRecipient = 'father'.obs;

  int get activeFilterCount {
    int count = 0;
    if (selectedGroup.value != 'All') count++;
    if (selectedFloor.value != 'All') count++;
    if (selectedStatus.value != 'All') count++;
    if (directoryFilter.value != 'all') count++;
    if (onlyWithAnniversaryDate.value) count++;
    if (onlyWithoutAnniversaryDate.value) count++;
    if (onlyWithFatherPhone.value) count++;
    if (onlyWithMotherPhone.value) count++;
    if (onlyWithBothPhones.value) count++;
    if (selectedSort.value != 'Default (Hostel First)') count++;
    return count;
  }

  @override
  void onInit() {
    super.onInit();
    if (isLeader.value && leaderGroup.value != null && leaderGroup.value!.isNotEmpty) {
      selectedGroup.value = leaderGroup.value!;
    }
    templateController.addListener(_onEditorChanged);
    templateNameController.addListener(_onEditorChanged);
    loadDashboard();
    searchController.addListener(() {
      searchQuery.value = searchController.text.trim();
    });
  }

  @override
  void onClose() {
    searchController.dispose();
    templateController.dispose();
    templateNameController.dispose();
    templateFocus.dispose();
    sendTimeController.dispose();
    testPhoneController.dispose();
    customWishPhoneController.dispose();
    customWishMessageController.dispose();
    super.onClose();
  }

  // --- Filter Selectors ---

  void selectGroup(String group) {
    if (isLeader.value) return;
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

  void toggleOnlyWithAnniversaryDate(bool val) {
    onlyWithAnniversaryDate.value = val;
    if (val) {
      onlyWithoutAnniversaryDate.value = false;
      if (directoryFilter.value == 'no_date') directoryFilter.value = 'has_date';
    }
  }

  void toggleOnlyWithoutAnniversaryDate(bool val) {
    onlyWithoutAnniversaryDate.value = val;
    if (val) {
      onlyWithAnniversaryDate.value = false;
      if (directoryFilter.value == 'has_date') directoryFilter.value = 'no_date';
    }
  }

  void toggleOnlyWithFatherPhone(bool val) {
    onlyWithFatherPhone.value = val;
  }

  void toggleOnlyWithMotherPhone(bool val) {
    onlyWithMotherPhone.value = val;
  }

  void toggleOnlyWithBothPhones(bool val) {
    onlyWithBothPhones.value = val;
  }

  bool isAlumni(AnniversaryStudentRecord s) => s.isAlumni;
  String? groupFor(AnniversaryStudentRecord s) => s.groupName;

  void resetAllFilters() {
    selectedGroup.value = isLeader.value ? (leaderGroup.value ?? 'All') : 'All';
    selectedFloor.value = 'All';
    selectedStatus.value = 'All';
    directoryFilter.value = 'all';
    onlyWithAnniversaryDate.value = false;
    onlyWithoutAnniversaryDate.value = false;
    onlyWithFatherPhone.value = false;
    onlyWithMotherPhone.value = false;
    onlyWithBothPhones.value = false;
    selectedSort.value = 'Default (Hostel First)';
  }

  // --- Filtered Directory List ---

  List<AnniversaryStudentRecord> get filteredStudents {
    final query = searchQuery.value.trim();
    final list = allStudents.where((s) {
      // Search term (Apple Contacts-style multi-token search)
      if (query.isNotEmpty) {
        final matches = AppleSearchUtils.matches(
          query: query,
          name: s.name,
          fatherName: s.fatherName,
          motherName: s.motherName,
          room: s.room,
          code: s.studentCode,
          phone: s.fatherPhone.isNotEmpty ? s.fatherPhone : s.motherPhone,
        );
        if (!matches) return false;
      }

      // Group filter
      if (selectedGroup.value != 'All') {
        final g = (s.groupName ?? '').toLowerCase().trim();
        final selG = selectedGroup.value.toLowerCase();
        if (selG == 'alumni') {
          if (!s.isAlumni && g != 'alumni') return false;
        } else {
          if (g != selG) return false;
        }
      }

      // Floor filter
      if (selectedFloor.value != 'All') {
        final expectedFloor = floorNumberOf(selectedFloor.value);
        final studentFloor = PhonebookStudent.floorOfRoom(s.room);
        if (studentFloor != expectedFloor) return false;
      }

      // Status filter
      final alumni = s.isAlumni;
      if (selectedStatus.value == 'Active Residents' && alumni) return false;
      if (selectedStatus.value == 'Alumni / Left' && !alumni) return false;

      if (directoryFilter.value == 'hostel' && alumni) return false;
      if (directoryFilter.value == 'alumni' && !alumni) return false;
      if (directoryFilter.value == 'has_date' && s.anniversaryDate.trim().isEmpty) return false;
      if (directoryFilter.value == 'no_date' && s.anniversaryDate.trim().isNotEmpty) return false;

      // Date / phone toggles
      if (onlyWithAnniversaryDate.value && s.anniversaryDate.trim().isEmpty) return false;
      if (onlyWithoutAnniversaryDate.value && s.anniversaryDate.trim().isNotEmpty) return false;
      if (onlyWithFatherPhone.value && !s.hasFatherPhone) return false;
      if (onlyWithMotherPhone.value && !s.hasMotherPhone) return false;
      if (onlyWithBothPhones.value && (!s.hasFatherPhone || !s.hasMotherPhone)) return false;

      return true;
    }).toList();

    // Sorting
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
      case 'Anniversary Date (Jan-Dec)':
        list.sort((a, b) {
          final dateA = a.anniversaryDate.length >= 5 ? a.anniversaryDate.substring(5) : '99-99';
          final dateB = b.anniversaryDate.length >= 5 ? b.anniversaryDate.substring(5) : '99-99';
          return dateA.compareTo(dateB);
        });
        break;
      case 'Default (Hostel First)':
      default:
        list.sort((a, b) {
          if (!a.isAlumni && b.isAlumni) return -1;
          if (a.isAlumni && !b.isAlumni) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }

    return list;
  }

  // --- Data Loading ---

  Future<void> loadDashboard() async {
    isLoading.value = true;
    error.value = '';
    try {
      final data = await _repository.fetchDashboard(
        group: isLeader.value ? leaderGroup.value : null,
      );
      dashboard.value = data;
      isAnniversaryEnabled.value = data.config.anniversaryEnabled;
      _loadTemplates(data.config);
      sendTimeController.text = data.config.sendTime;
      logs.value = data.recentLogs;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAllStudents({String? query}) async {
    if (isLoadingStudents.value) return;
    isLoadingStudents.value = true;
    try {
      final list = await _repository.fetchAllStudents(
        search: query ?? (searchController.text.trim().isNotEmpty ? searchController.text.trim() : null),
        group: isLeader.value ? leaderGroup.value : null,
      );
      allStudents.value = list;
    } catch (e) {
      AppSnackbar.warning('Directory Error', 'Could not load anniversary directory: $e');
    } finally {
      isLoadingStudents.value = false;
    }
  }

  Future<void> callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      AppSnackbar.warning('No Phone', 'No valid phone number to call.');
      return;
    }
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      AppSnackbar.warning('Call Failed', 'Could not start phone call to $clean.');
    }
  }

  Future<void> loadLogs({String? date}) async {
    isLoadingLogs.value = true;
    try {
      final targetDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final list = await _repository.fetchLogs(
        from: targetDate,
        group: isLeader.value ? leaderGroup.value : null,
      );
      logs.value = list;
    } catch (e) {
      AppSnackbar.warning('Logs Error', 'Could not load anniversary logs: $e');
    } finally {
      isLoadingLogs.value = false;
    }
  }

  // --- Message Formatting ---

  /// Inserts [tag] into the template where the cursor is (replacing any
  /// selected text); at the end only when the field was never focused.
  void insertTemplateVariable(String tag) {
    final c = templateController;
    final text = c.text;
    final sel = c.selection;
    var start = sel.isValid ? sel.start : text.length;
    var end = sel.isValid ? sel.end : text.length;
    if (start < 0 || end < 0) {
      start = end = text.length;
    }
    final before = text.substring(0, start);
    final after = text.substring(end);
    final wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
    final lead = before.isNotEmpty && wordChar.hasMatch(before[before.length - 1]) ? ' ' : '';
    final trail = after.isNotEmpty && wordChar.hasMatch(after[0]) ? ' ' : '';
    final insert = '$lead$tag$trail';
    final caret = before.length + lead.length + tag.length + trail.length;
    c.value = TextEditingValue(
      text: '$before$insert$after',
      selection: TextSelection.collapsed(offset: caret),
    );
    templateFocus.requestFocus();
  }

  /// A real celebrant for the template preview, else a sample one.
  AnniversaryStudentRecord get previewRecord {
    final today = dashboard.value?.todaysAnniversaries;
    if (today != null && today.isNotEmpty) return today.first;
    return const AnniversaryStudentRecord(
      studentId: 0,
      name: 'Aarav Patel',
      studentCode: '0000',
      room: '101',
      fatherName: 'Ramesh Kumar Patel',
      motherName: 'Sunita Patel',
      anniversaryDate: '2000-01-01',
    );
  }

  String formatMessage(String template, AnniversaryStudentRecord record, String recipientType) {
    final firstName = record.name.trim().split(RegExp(r'\s+')).first;
    final fName = record.fatherName.trim();
    final mName = record.motherName.trim();
    final father = splitPersonName(fName);
    final mother = splitPersonName(mName);
    final parentsNames = fName.isNotEmpty && mName.isNotEmpty
        ? '$fName & $mName'
        : (fName.isNotEmpty ? fName : (mName.isNotEmpty ? mName : 'Parents of ${record.name}'));

    final recipientName = recipientType == 'mother'
        ? (mName.isNotEmpty ? mName : parentsNames)
        : (fName.isNotEmpty ? fName : parentsNames);

    final years = record.yearsOfMarriage?.toString() ?? '';

    return template
        .replaceAll(RegExp(r'\{father_first_name\}', caseSensitive: false), father.first)
        .replaceAll(RegExp(r'\{father_middle_name\}', caseSensitive: false), father.middle)
        .replaceAll(RegExp(r'\{father_last_name\}', caseSensitive: false), father.last)
        .replaceAll(RegExp(r'\{mother_first_name\}', caseSensitive: false), mother.first)
        .replaceAll(RegExp(r'\{mother_middle_name\}', caseSensitive: false), mother.middle)
        .replaceAll(RegExp(r'\{mother_last_name\}', caseSensitive: false), mother.last)
        .replaceAll(RegExp(r'\{parents_names\}', caseSensitive: false), parentsNames)
        .replaceAll(RegExp(r'\{father_name\}', caseSensitive: false), fName.isNotEmpty ? fName : 'Father')
        .replaceAll(RegExp(r'\{mother_name\}', caseSensitive: false), mName.isNotEmpty ? mName : 'Mother')
        .replaceAll(RegExp(r'\{recipient_name\}', caseSensitive: false), recipientName)
        .replaceAll(RegExp(r'\{years\}', caseSensitive: false), years)
        .replaceAll(RegExp(r'\{student_name\}', caseSensitive: false), record.name)
        .replaceAll(RegExp(r'\{name\}', caseSensitive: false), record.name)
        .replaceAll(RegExp(r'\{first_name\}', caseSensitive: false), firstName)
        .replaceAll(RegExp(r'\{room\}', caseSensitive: false), record.room)
        .replaceAll(RegExp(r'\{room_number\}', caseSensitive: false), record.room)
        .replaceAll(RegExp(r'\{student_code\}', caseSensitive: false), record.studentCode)
        .replaceAll(RegExp(r'\{code\}', caseSensitive: false), record.studentCode);
  }

  // --- Wishing Actions ---

  /// Which WhatsApp number to send from (asked only when several are linked).
  Future<SendFromChoice?> _pickNumber() => pickSendFromAccount(purpose: 'anniversary');

  /// Send automated wish via Server Bot to BOTH Father and Mother.
  Future<void> wishBoth(AnniversaryStudentRecord record) async {
    final from = await _pickNumber();
    if (from == null) return;
    isTriggering.value = true;
    try {
      final res = await _repository.sendSingleWish(
        studentId: record.studentId,
        target: 'both',
        accountId: from.accountId,
      );
      final count = res['sentCount'] ?? 2;
      AppSnackbar.success(
        'Anniversary Wishes Sent! 💍',
        'Greetings delivered to both parents of ${record.name} ($count messages).',
      );
      await loadDashboard();
    } catch (e) {
      AppSnackbar.error('Failed to Send', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isTriggering.value = false;
    }
  }

  /// Send automated wish via Server Bot to Father.
  Future<void> wishFather(AnniversaryStudentRecord record) async {
    if (!record.hasFatherPhone) {
      AppSnackbar.warning('No Phone', 'Father phone number is not available for ${record.name}.');
      return;
    }
    final from = await _pickNumber();
    if (from == null) return;
    isTriggering.value = true;
    try {
      await _repository.sendSingleWish(
        studentId: record.studentId,
        target: 'father',
        accountId: from.accountId,
      );
      AppSnackbar.success(
        'Wish Sent to Father! 🎩',
        'Delivered to ${record.fatherName} (${record.fatherPhone}).',
      );
      await loadDashboard();
    } catch (e) {
      AppSnackbar.error('Failed to Send', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isTriggering.value = false;
    }
  }

  /// Send automated wish via Server Bot to Mother.
  Future<void> wishMother(AnniversaryStudentRecord record) async {
    if (!record.hasMotherPhone) {
      AppSnackbar.warning('No Phone', 'Mother phone number is not available for ${record.name}.');
      return;
    }
    final from = await _pickNumber();
    if (from == null) return;
    isTriggering.value = true;
    try {
      await _repository.sendSingleWish(
        studentId: record.studentId,
        target: 'mother',
        accountId: from.accountId,
      );
      AppSnackbar.success(
        'Wish Sent to Mother! 🌸',
        'Delivered to ${record.motherName} (${record.motherPhone}).',
      );
      await loadDashboard();
    } catch (e) {
      AppSnackbar.error('Failed to Send', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isTriggering.value = false;
    }
  }

  /// Launch WhatsApp directly on the device with prefilled message.
  /// This enables wishing with ANY WhatsApp number or account available on this phone!
  Future<void> wishViaDeviceWhatsApp({
    required String phone,
    required AnniversaryStudentRecord record,
    required String recipientType,
    String? customMessage,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      AppSnackbar.warning('No Phone', 'No phone number available to open in WhatsApp.');
      return;
    }

    final template = customMessage ??
        (dashboard.value?.config.anniversaryMessageTemplate ?? templateController.text);
    final text = formatMessage(template, record, recipientType);

    await openWhatsAppDirect(cleanPhone, customText: text);
  }

  /// Direct WhatsApp app launcher with external fallback.
  Future<void> openWhatsAppDirect(String phone, {String? customText}) async {
    String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.length == 10) {
      formattedPhone = '91$formattedPhone';
    }

    final query = customText != null ? '?text=${Uri.encodeComponent(customText)}' : '';
    final uri = Uri.parse('whatsapp://send?phone=$formattedPhone$query');
    final webUri = Uri.parse('https://wa.me/$formattedPhone$query');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        AppSnackbar.warning('WhatsApp not installed', 'Could not open WhatsApp on this phone.');
      }
    }
  }

  /// Send wish to a custom or alternate phone number.
  Future<void> wishCustomNumber({
    required AnniversaryStudentRecord record,
    required String phone,
    required String recipientType,
    required bool viaBot,
    String? customText,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      AppSnackbar.warning('Invalid Number', 'Please enter a valid 10-digit phone number.');
      return;
    }

    final template = customText ??
        (dashboard.value?.config.anniversaryMessageTemplate ?? templateController.text);
    final message = formatMessage(template, record, recipientType);

    if (viaBot) {
      final from = await _pickNumber();
      if (from == null) return;
      isTriggering.value = true;
      try {
        await _repository.sendSingleWish(
          studentId: record.studentId,
          target: recipientType,
          customPhone: cleanPhone,
          customMessage: message,
          accountId: from.accountId,
        );
        AppSnackbar.success(
          'Custom Wish Sent! 💍',
          'Delivered to +$cleanPhone via WhatsApp bot.',
        );
        await loadDashboard();
      } catch (e) {
        AppSnackbar.error('Failed to Send', e.toString().replaceFirst('Exception: ', ''));
      } finally {
        isTriggering.value = false;
      }
    } else {
      await openWhatsAppDirect(cleanPhone, customText: message);
    }
  }

  /// Sweep and send all anniversary wishes for today.
  Future<void> sendAllWishesToday() async {
    final count = dashboard.value?.todaysAnniversaries.length ?? 0;
    if (count == 0) {
      AppSnackbar.info('No Celebrants', 'No parents have anniversaries today.');
      return;
    }

    final from = await _pickNumber();
    if (from == null) return;
    isTriggering.value = true;
    try {
      final res = await _repository.triggerWishes(force: true, accountId: from.accountId);
      final sentCount = res['count'] ?? count;
      AppSnackbar.success(
        'All Wishes Dispatched! 💍🎉',
        'Successfully dispatched greetings to $sentCount parents today.',
      );
      await loadDashboard();
    } catch (e) {
      AppSnackbar.error('Trigger Failed', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isTriggering.value = false;
    }
  }

  /// Send test anniversary wish to a given phone number.
  Future<void> sendTestWish(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 10) {
      AppSnackbar.warning('Invalid Phone', 'Please enter a valid 10-digit number to receive the test wish.');
      return;
    }

    final from = await _pickNumber();
    if (from == null) return;
    isTriggering.value = true;
    try {
      await _repository.triggerWishes(testPhone: clean, accountId: from.accountId);
      AppSnackbar.success(
        'Test Wish Sent! 🧪',
        'Sample parents anniversary wish sent to +$clean.',
      );
    } catch (e) {
      AppSnackbar.error('Test Wish Failed', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isTriggering.value = false;
    }
  }

  /// Save settings & message template.
  // ============================================================
  // Template library
  // ============================================================

  AnniversaryTemplate? _findTemplate(String? id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool isActiveTemplate(AnniversaryTemplate t) => activeTemplateId.value == t.id;

  /// Body of the active template, trimmed ('' if none): what the server sends.
  String get activeBody => _findTemplate(activeTemplateId.value)?.body.trim() ?? '';

  String _templatesSnapshot() => jsonEncode({
        'active': activeTemplateId.value,
        'templates': templates.map((t) => t.toJson()).toList(),
      });

  bool get hasUnsavedTemplateChanges => _templatesSnapshot() != _savedTemplatesSnapshot;

  /// Fills the library from the server. A server with no saved library yet (or an older one)
  /// shows its single message as the first, active template.
  void _loadTemplates(AnniversaryConfigModel config) {
    var list = List<AnniversaryTemplate>.from(config.templates);
    var active = config.activeTemplateId;
    if (list.isEmpty) {
      list = [
        AnniversaryTemplate(
          id: _newTemplateId(),
          name: 'Anniversary wish 1',
          body: config.anniversaryMessageTemplate,
        ),
      ];
      active = list.first.id;
    } else if (!list.any((t) => t.id == active)) {
      active = list.first.id;
    }
    templates.assignAll(list);
    activeTemplateId.value = active;
    _openEditor(active);
    _savedTemplatesSnapshot = _templatesSnapshot();
  }

  String _newTemplateId() => 'atpl_${DateTime.now().microsecondsSinceEpoch}';

  void addTemplate() {
    if (templates.length >= maxTemplates) {
      AppSnackbar.warning('Too Many Templates', 'You can keep up to $maxTemplates templates. Delete one you no longer use.');
      return;
    }
    final template = AnniversaryTemplate(
      id: _newTemplateId(),
      name: 'Anniversary wish ${templates.length + 1}',
      body: 'Dear {parents_names}, 💍🎉 Wishing you a very Happy Marriage Anniversary from Hari Saurabh Hostel family! 🌟✨ - HSH Warden Team',
    );
    templates.add(template);
    activeTemplateId.value ??= template.id;
    _openEditor(template.id);
  }

  void editTemplate(String id) => _openEditor(id);

  void setActiveTemplate(String id) {
    if (_findTemplate(id) == null) return;
    activeTemplateId.value = id;
  }

  void deleteTemplate(String id) {
    final template = _findTemplate(id);
    if (template == null) return;
    if (isActiveTemplate(template)) {
      AppSnackbar.warning('Template Is Active', 'Set another template as active before deleting this one.');
      return;
    }
    templates.removeWhere((t) => t.id == id);
    if (editingTemplateId.value == id) _openEditor(activeTemplateId.value);
  }

  void _openEditor(String? id) {
    final template = _findTemplate(id);
    editingTemplateId.value = template?.id;
    _loadingEditor = true;
    templateNameController.text = template?.name ?? '';
    templateController.text = template?.body ?? '';
    _loadingEditor = false;
  }

  /// Copies the editor text into the template being edited.
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

  /// Why the library can't be saved yet, or null. Mirrors the checks hsh_api makes.
  String? _templateProblem() {
    if (activeBody.isEmpty) {
      return 'The active template is empty. Write a message or pick another template.';
    }
    if (templates.length > maxTemplates) {
      return 'You can keep up to $maxTemplates templates. Delete the ones you no longer use.';
    }
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

  Future<void> saveSettings() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final problem = _templateProblem();
    if (problem != null) {
      AppSnackbar.warning('Check Templates', problem);
      return;
    }

    isSaving.value = true;
    try {
      final updated = await _repository.saveConfig(
        AnniversaryConfigModel(
          anniversaryEnabled: isAnniversaryEnabled.value,
          sendTime: sendTimeController.text.trim().isNotEmpty ? sendTimeController.text.trim() : '08:30',
          anniversaryMessageTemplate: activeBody,
          templates: templates.toList(),
          activeTemplateId: activeTemplateId.value,
        ),
      );
      _savedTemplatesSnapshot = _templatesSnapshot();
      dashboard.value = dashboard.value != null
          ? AnniversaryDashboardData(
              config: updated,
              todaysAnniversaries: dashboard.value!.todaysAnniversaries,
              tomorrowsAnniversaries: dashboard.value!.tomorrowsAnniversaries,
              recentLogs: dashboard.value!.recentLogs,
              isWhatsAppConnected: dashboard.value!.isWhatsAppConnected,
              senderPhone: dashboard.value!.senderPhone,
              isLeader: dashboard.value!.isLeader,
              leaderGroup: dashboard.value!.leaderGroup,
            )
          : null;
      AppSnackbar.success('Settings Saved', 'Anniversary greetings configuration updated successfully.');
    } catch (e) {
      AppSnackbar.error('Save Failed', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isSaving.value = false;
    }
  }
}
