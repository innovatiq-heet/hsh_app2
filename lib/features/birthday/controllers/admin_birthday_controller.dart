import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/birthday/birthday_models.dart';
import '../../../core/network/repository/birthday/birthday_repository.dart';
import '../../../core/utils/app_snackbar.dart';

class AdminBirthdayController extends GetxController {
  final BirthdayRepository _repository = BirthdayRepository();

  final Rxn<BirthdayDashboardData> dashboard = Rxn<BirthdayDashboardData>();
  final RxList<BirthdayStudentModel> allStudents = <BirthdayStudentModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isTriggering = false.obs;
  final RxBool isLoadingStudents = false.obs;
  final RxString error = ''.obs;

  final RxInt selectedTab = 0.obs;

  // Template editor & config fields
  late TextEditingController templateController;
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
  final RxBool isPairingLoading = false.obs;
  final RxBool isCheckingStatus = false.obs;
  final RxString connectedPhone = ''.obs;

  @override
  void onInit() {
    super.onInit();
    templateController = TextEditingController();
    testPhoneController = TextEditingController();
    adminPhoneController = TextEditingController();
    searchController = TextEditingController();
    pairPhoneController = TextEditingController();

    loadDashboard();
    fetchWhatsAppStatus();
  }

  @override
  void onClose() {
    templateController.dispose();
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
      templateController.text = data.config.messageTemplate;
      adminPhoneController.text = data.config.adminNotificationPhone ?? '';

      // Sync WA connection state
      if (data.senderPhone != null && data.senderPhone!.isNotEmpty) {
        connectedPhone.value = data.senderPhone!;
        waStatus.value = 'open';
      }
    } catch (e) {
      debugPrint('[AdminBirthdayController] loadDashboard error: $e');
      error.value = 'Failed to load birthday dashboard. Pull down to retry.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchWhatsAppStatus() async {
    isCheckingStatus.value = true;
    try {
      final res = await _repository.getWhatsAppStatus();
      if (res.isNotEmpty) {
        waStatus.value = res['status']?.toString() ?? 'disconnected';
        waQr.value = res['qr']?.toString() ?? '';
        final user = res['user'];
        if (user is Map && user['phone'] != null) {
          connectedPhone.value = user['phone'].toString();
        } else {
          connectedPhone.value = '';
        }
      }
    } catch (e) {
      debugPrint('[AdminBirthdayController] fetchWhatsAppStatus error: $e');
    } finally {
      isCheckingStatus.value = false;
    }
  }

  Future<void> requestPairingCode() async {
    final phone = pairPhoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 10) {
      AppSnackbar.warning('Invalid Number', 'Enter your full WhatsApp number with country code (e.g. 919876543210).');
      return;
    }

    isPairingLoading.value = true;
    pairingCode.value = '';
    try {
      final code = await _repository.requestPairingCode(phone);
      pairingCode.value = code;
      AppSnackbar.success('Pairing Code Ready', 'Enter code in WhatsApp > Linked Devices.');
    } catch (e) {
      AppSnackbar.error('Pairing Failed', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isPairingLoading.value = false;
    }
  }

  Future<void> disconnectWhatsAppSession() async {
    try {
      await _repository.disconnectWhatsApp();
      pairingCode.value = '';
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
      AppSnackbar.error('Failed to update', e.toString());
    }
  }

  Future<void> saveSettings() async {
    final current = dashboard.value?.config;
    if (current == null) return;

    isSaving.value = true;
    try {
      final updated = await _repository.saveConfig(
        current.copyWith(
          isEnabled: isAutoEnabled.value,
          sendTime: sendTime.value,
          targetAudience: targetAudience.value,
          preferWhatsAppNumber: preferWhatsApp.value,
          adminNotificationPhone: adminPhoneController.text.trim().isEmpty ? null : adminPhoneController.text.trim(),
          messageTemplate: templateController.text.trim(),
        ),
      );
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
      AppSnackbar.error('Save Failed', e.toString());
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> triggerAllToday() async {
    isTriggering.value = true;
    try {
      final result = await _repository.triggerWishes();
      final count = result['count'] ?? 0;
      AppSnackbar.success(
        'Wishes Dispatched',
        'Successfully dispatched birthday greetings to $count celebrant(s).',
      );
      await loadDashboard(); // Reload logs & status
    } catch (e) {
      AppSnackbar.error('Trigger Failed', e.toString());
    } finally {
      isTriggering.value = false;
    }
  }

  Future<void> sendTestWish() async {
    final phone = testPhoneController.text.trim();
    if (phone.length < 10) {
      AppSnackbar.warning('Invalid Number', 'Please enter a valid 10-digit mobile number.');
      return;
    }

    isTriggering.value = true;
    try {
      await _repository.triggerWishes(testPhone: phone);
      AppSnackbar.success('Test Wish Sent', 'Delivered test birthday greeting to $phone.');
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

  Future<void> openWhatsApp(String phone, {String? customText}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final fullNumber = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
    final text = Uri.encodeComponent(customText ?? 'Hare Krishna! Happy Birthday from HSH!');
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
