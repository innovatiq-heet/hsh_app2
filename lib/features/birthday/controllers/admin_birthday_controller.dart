import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/birthday/birthday_models.dart';
import '../../../core/network/repository/birthday/birthday_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../phonebook/services/phonebook_database_service.dart';
import '../../phonebook/services/phonebook_sync_service.dart';

class AdminBirthdayController extends GetxController {
  final BirthdayRepository _repository = BirthdayRepository();

  final Rxn<BirthdayDashboardData> dashboard = Rxn<BirthdayDashboardData>();
  final RxList<BirthdayStudentModel> allStudents = <BirthdayStudentModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isTriggering = false.obs;
  final RxBool hasSentToday = false.obs;
  final RxBool isLoadingStudents = false.obs;
  final RxString error = ''.obs;

  final RxInt selectedTab = 0.obs;

  // Template editor & config fields
  /// Body of the template open in the editor (see [editingTemplateId]).
  late TextEditingController templateController;
  late TextEditingController templateNameController;
  late TextEditingController testPhoneController;
  late TextEditingController adminPhoneController;
  late TextEditingController searchController;
  late TextEditingController pairPhoneController;

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
  final RxList<BirthdayTemplate> templates = <BirthdayTemplate>[].obs;
  final RxMap<String, String> activeTemplateIds = <String, String>{}.obs;
  final RxString editingAudience = BirthdayAudience.student.obs;
  final RxnString editingTemplateId = RxnString();
  bool _loadingEditor = false;
  String _savedTemplatesSnapshot = '';

  @override
  void onInit() {
    super.onInit();
    templateController = TextEditingController()..addListener(_onEditorChanged);
    templateNameController = TextEditingController()..addListener(_onEditorChanged);
    testPhoneController = TextEditingController();
    adminPhoneController = TextEditingController();
    searchController = TextEditingController();
    pairPhoneController = TextEditingController();

    _checkIfAlreadySentToday();
    _loadPhonebookInfo();
    loadDashboard();
    fetchWhatsAppStatus();
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
      final data = await _repository.fetchDashboard();
      dashboard.value = data;

      // Sync form fields
      isAutoEnabled.value = data.config.isEnabled;
      sendTime.value = data.config.sendTime;
      targetAudience.value = data.config.targetAudience;
      preferWhatsApp.value = data.config.preferWhatsAppNumber;
      await _loadTemplates(data.config);
      adminPhoneController.text = data.config.adminNotificationPhone ?? '';

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
      final todays = data.todaysBirthdays;
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
      if (info.isEmpty) {
        final result = await PhonebookSyncService.instance.syncDirectory();
        if (result.success) {
          info = await PhonebookDatabaseService.instance.groupInfoByBankCode();
        }
      }
      _phonebookInfo.assignAll(info);
    } catch (e) {
      debugPrint('[AdminBirthdayController] phonebook lookup unavailable: $e');
    }
  }

  PhonebookGroupInfo? _phonebookInfoFor(BirthdayStudentModel s) =>
      _phonebookInfo[PhonebookDatabaseService.normalizeBankCode(s.studentCode)];

  String? groupFor(BirthdayStudentModel s) => groupFrom(s, _phonebookInfoFor(s));

  bool isAlumni(BirthdayStudentModel s) => alumniFrom(s, _phonebookInfoFor(s));

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
    // 1. Validation: Ensure WhatsApp device is linked
    if (!isWhatsAppLinked) {
      AppSnackbar.warning(
        'WhatsApp Not Connected',
        'Please link your WhatsApp device first before sending birthday wishes.',
      );
      if (onNeedLinkDevice != null) {
        onNeedLinkDevice();
      }
      return;
    }

    // 2. Ensure there are celebrants to send to
    final countToTrigger = dashboard.value?.todaysBirthdays.length ?? 0;
    if (countToTrigger == 0) {
      AppSnackbar.info('No Celebrants', 'There are no birthdays registered for today.');
      return;
    }

    isTriggering.value = true;
    try {
      // Auto-save edited templates so the backend dispatches with the latest ones
      await _autoSaveTemplates();

      final result = await _repository.triggerWishes();
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

    // Validation: Ensure WhatsApp device is linked
    if (!isWhatsAppLinked) {
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
      // Auto-save edited templates so the backend delivers the latest ones
      await _autoSaveTemplates();

      final res = await _repository.triggerWishes(testPhone: phone);
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
      final students = await _repository.fetchAllStudents(search: query);
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

  static String defaultBodyFor(String audience) =>
      audience == BirthdayAudience.parent ? defaultParentTemplate : defaultStudentTemplate;

  /// Builds the template library from the API config, falling back to the local
  /// [cache] while the API has no `templates` field. Every audience ends up with
  /// at least one template and a valid active id.
  static ({List<BirthdayTemplate> templates, Map<String, String> active}) resolveTemplates(
    BirthdayConfigModel config,
    Map<String, dynamic>? cache,
  ) {
    final fromServer = config.templatesFromServer && config.templates.isNotEmpty;
    final templates = <BirthdayTemplate>[];
    final active = <String, String>{};
    if (fromServer) {
      templates.addAll(config.templates);
      if (config.activeStudentTemplateId != null) active[BirthdayAudience.student] = config.activeStudentTemplateId!;
      if (config.activeParentTemplateId != null) active[BirthdayAudience.parent] = config.activeParentTemplateId!;
    } else if (cache != null) {
      templates.addAll(BirthdayTemplate.listFromJson(cache['templates']));
      final cachedActive = cache['active'];
      if (cachedActive is Map) {
        cachedActive.forEach((k, v) => active['$k'] = '$v');
      }
    }

    for (final audience in BirthdayAudience.all) {
      final sentBody = (audience == BirthdayAudience.student ? config.messageTemplate : config.parentMessageTemplate).trim();
      final forAudience = templates.where((t) => t.audience == audience).toList();

      if (forAudience.isEmpty) {
        final first = BirthdayTemplate(
          id: 'default_$audience',
          name: audience == BirthdayAudience.parent ? 'Default parent wish' : 'Default student wish',
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
    final label = audience == BirthdayAudience.parent ? 'Parent' : 'Student';
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
  BirthdayConfigModel _withTemplates(BirthdayConfigModel config) {
    return config.copyWith(
      messageTemplate: activeBody(BirthdayAudience.student),
      parentMessageTemplate: activeBody(BirthdayAudience.parent),
      templates: templates.toList(),
      activeStudentTemplateId: activeTemplateIds[BirthdayAudience.student],
      activeParentTemplateId: activeTemplateIds[BirthdayAudience.parent],
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
    final resolved = resolveTemplates(config, cache);
    templates.assignAll(resolved.templates);
    activeTemplateIds.assignAll(resolved.active);
    await _markTemplatesSaved();
    _openEditor(activeTemplateIds[editingAudience.value]);
  }

  Future<void> _markTemplatesSaved() async {
    _savedTemplatesSnapshot = _templatesSnapshot();
    try {
      await (await SharedPreferences.getInstance()).setString(_templatesCacheKey, _savedTemplatesSnapshot);
    } catch (e) {
      debugPrint('[AdminBirthdayController] template cache write failed: $e');
    }
  }

  /// Saves template edits before a send so the server uses what the admin sees.
  Future<void> _autoSaveTemplates() async {
    final config = dashboard.value?.config;
    if (config == null || !hasUnsavedTemplateChanges || _templateProblem() != null) return;
    try {
      await _repository.saveConfig(_withTemplates(config));
      await _markTemplatesSaved();
    } catch (_) {}
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

  /// Formats the greeting message for a student based on current template settings
  String formatWishMessage(BirthdayStudentModel student) {
    // Manual sends go to the student, so they use the active student template.
    String template = activeBody(BirthdayAudience.student);
    if (template.isEmpty) {
      template = dashboard.value?.config.messageTemplate ?? '';
    }
    if (template.isEmpty) {
      template = 'Hare Krishna {first_name}! Wishing you a very Happy Birthday from Hari Saurabh Hostel!';
    }

    final fullName = student.name.trim();
    final firstName = fullName.isNotEmpty ? fullName.split(' ').first : 'Student';
    final room = (student.room.isEmpty || student.room == 'N/A') ? '' : student.room;
    final code = student.studentCode;

    return fillTemplate(template, firstName: firstName, fullName: fullName, room: room, code: code);
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
