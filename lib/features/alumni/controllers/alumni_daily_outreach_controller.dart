import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../../core/network/repository/alumni/alumni_repository.dart';
import '../../../core/network/repository/birthday/birthday_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../../phonebook/services/phonebook_database_service.dart';

/// Tabs of the Daily Alumni Connect screen.
enum OutreachTab { today, history, message }

/// Daily Alumni Connect: each day a leader gets a few alumni of their group
/// (5 by default) to greet on WhatsApp. An admin can look at any group and
/// edit the shared message template.
class AlumniDailyOutreachController extends GetxController {
  AlumniDailyOutreachController({AlumniRepository? repository})
      : _repository = repository ?? Get.find<AlumniRepository>();

  final AlumniRepository _repository;

  final RxBool isLoading = false.obs;

  /// Why the first load failed (empty when it didn't); later refresh errors
  /// keep the data on screen and show a snackbar instead.
  final RxString loadError = ''.obs;
  final RxBool isSaving = false.obs;
  final RxBool isHistoryLoading = false.obs;
  final RxString historyError = ''.obs;
  final RxBool historyLoaded = false.obs;
  final RxBool isLeader = false.obs;
  final RxBool isAdmin = false.obs;
  final RxString reachabilityFilter = 'all'.obs;
  final RxSet<int> contactBusyIds = <int>{}.obs;

  final RxString currentGroup = 'Param'.obs;
  final RxString adminSelectedGroup = 'Param'.obs;
  final List<String> availableGroups = const ['Param', 'Pavitra', 'Pulkit', 'Paramanand'];

  final Rxn<AlumniDailyOutreachDataModel> outreachData = Rxn<AlumniDailyOutreachDataModel>();
  final RxList<AlumniOutreachHistoryModel> historyList = <AlumniOutreachHistoryModel>[].obs;

  final Rx<OutreachTab> selectedTab = OutreachTab.today.obs;
  final TextEditingController templateController = TextEditingController();

  /// A leader's own wording for one alumnus (by student id), used instead of
  /// the template.
  final RxMap<int, String> customMessageMap = <int, String>{}.obs;

  /// Alumni with a send, mark or skip in flight.
  final RxSet<int> busyIds = <int>{}.obs;

  /// True while Send All is going through today's pending alumni.
  final RxBool isSendingAll = false.obs;

  /// Pause between two sends of Send All, so WhatsApp isn't flooded.
  static const sendAllGap = Duration(milliseconds: 700);

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<SessionStore>()) {
      final session = Get.find<SessionStore>().currentSession;
      isLeader.value = session?.role == UserRole.leader;
      isAdmin.value = session?.role == UserRole.admin;
    }
    loadDailyOutreach();
  }

  @override
  void onClose() {
    templateController.dispose();
    super.onClose();
  }

  static String _message(Object e) => e.toString().replaceAll('Exception: ', '');

  // ------------------------------------------------------------------ today

  /// Today's alumni: the ones still to contact first, then those done.
  List<AlumniOutreachStudentModel> get orderedStudents {
    final all = outreachData.value?.students ?? const <AlumniOutreachStudentModel>[];
    return [...all.where((s) => s.isPending), ...all.where((s) => s.isMessaged)];
  }

  int get pendingCount => (outreachData.value?.students ?? const []).where((s) => s.isPending).length;

  /// Loads today's alumni for the leader's group, or the admin's chosen group.
  Future<void> loadDailyOutreach({String? group}) async {
    isLoading.value = true;
    loadError.value = '';
    try {
      final targetGroup = isLeader.value ? null : (group ?? adminSelectedGroup.value);
      final data = await _repository.getDailyOutreach(group: targetGroup);
      outreachData.value = data;
      currentGroup.value = data.groupName;
      if (!isLeader.value && group != null) {
        adminSelectedGroup.value = data.groupName;
      }
      if (templateController.text.trim().isEmpty) {
        templateController.text = data.messageTemplate;
      }
    } catch (e) {
      developer.log('loadDailyOutreach error: $e', name: 'AlumniOutreach');
      if (outreachData.value == null) {
        loadError.value = _message(e);
      } else {
        AppSnackbar.error('Could Not Refresh', _message(e));
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Pull-to-refresh: today's list, and the history when it is open.
  Future<void> refreshAll() async {
    await Future.wait([
      loadDailyOutreach(),
      if (selectedTab.value == OutreachTab.history) loadHistory(),
    ]);
  }

  void selectTab(OutreachTab tab) {
    selectedTab.value = tab;
    if (tab == OutreachTab.history && !historyLoaded.value && !isHistoryLoading.value) {
      loadHistory();
    }
  }

  /// Changes the group (admin only).
  void switchAdminGroup(String newGroup) {
    if (isLeader.value || adminSelectedGroup.value == newGroup) return;
    adminSelectedGroup.value = newGroup;
    customMessageMap.clear();
    historyLoaded.value = false;
    historyList.clear();
    loadDailyOutreach(group: newGroup);
    if (selectedTab.value == OutreachTab.history) loadHistory();
  }

  // ---------------------------------------------------------------- history

  /// Past connects of the group.
  Future<void> loadHistory() async {
    isHistoryLoading.value = true;
    historyError.value = '';
    try {
      final targetGroup = isLeader.value ? null : adminSelectedGroup.value;
      historyList.assignAll(await _repository.getOutreachHistory(group: targetGroup, limit: 100));
      historyLoaded.value = true;
    } catch (e) {
      developer.log('loadHistory error: $e', name: 'AlumniOutreach');
      historyError.value = _message(e);
    } finally {
      isHistoryLoading.value = false;
    }
  }

  /// History grouped by day (`yyyy-MM-dd`), newest day first, keeping the
  /// server's order within a day.
  List<MapEntry<String, List<AlumniOutreachHistoryModel>>> get historyByDay {
    final days = <String, List<AlumniOutreachHistoryModel>>{};
    for (final h in historyList) {
      if (reachabilityFilter.value != 'all' && h.whatsappReachability != reachabilityFilter.value) continue;
      final day = h.outreachDate.length >= 10 ? h.outreachDate.substring(0, 10) : h.outreachDate;
      days.putIfAbsent(day, () => []).add(h);
    }
    final entries = days.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  Future<bool> updateContact(AlumniOutreachHistoryModel item, {String? number, String? reachability}) async {
    if (!isAdmin.value || !contactBusyIds.add(item.studentId)) return false;
    try {
      await _repository.updateOutreachContact(item.studentId, whatsappNumber: number, reachability: reachability);
      await Future.wait([loadHistory(), loadDailyOutreach()]);
      AppSnackbar.success('Contact Updated', number != null ? '${item.name}\'s WhatsApp number was updated.' : '${item.name}\'s WhatsApp status was updated.');
      return true;
    } catch (e) {
      AppSnackbar.error('Contact Not Updated', _message(e));
      return false;
    } finally {
      contactBusyIds.remove(item.studentId);
    }
  }

  Future<List<Map<String, dynamic>>> contactChanges(int studentId) =>
      _repository.getOutreachContactChanges(studentId);

  // ---------------------------------------------------------------- message

  /// The template with this alumnus's details filled in.
  String templateMessageFor(AlumniOutreachStudentModel student) {
    final template = templateController.text.trim().isNotEmpty
        ? templateController.text
        : outreachData.value?.messageTemplate ?? '';

    final firstName = student.name.trim().split(RegExp(r'\s+')).first;
    final leaderName = (Get.isRegistered<SessionStore>() &&
            Get.find<SessionStore>().currentSession?.name.trim().isNotEmpty == true)
        ? Get.find<SessionStore>().currentSession!.name
        : 'Group Leader';

    return template
        .replaceAll(RegExp(r'{name}', caseSensitive: false), student.name)
        .replaceAll(RegExp(r'{first_name}', caseSensitive: false), firstName)
        .replaceAll(RegExp(r'{alumni_name}', caseSensitive: false), student.name)
        .replaceAll(RegExp(r'{group_name}', caseSensitive: false), currentGroup.value)
        .replaceAll(RegExp(r'{group}', caseSensitive: false), currentGroup.value)
        .replaceAll(RegExp(r'{room}', caseSensitive: false), student.pastRoom)
        .replaceAll(RegExp(r'{leader_name}', caseSensitive: false), leaderName);
  }

  /// What will be sent to this alumnus: the leader's own wording if any,
  /// otherwise the filled-in template.
  String getFormattedMessage(AlumniOutreachStudentModel student) {
    final custom = customMessageMap[student.studentId];
    if (custom != null && custom.trim().isNotEmpty) return custom;
    return templateMessageFor(student);
  }

  bool hasCustomMessage(int studentId) => (customMessageMap[studentId] ?? '').trim().isNotEmpty;

  /// Sets this alumnus's own message; an empty [text] goes back to the template.
  void setCustomMessage(int studentId, String text) {
    if (text.trim().isEmpty) {
      customMessageMap.remove(studentId);
    } else {
      customMessageMap[studentId] = text.trim();
    }
  }

  // ---------------------------------------------------------------- actions

  /// Opens WhatsApp with the message. A first send also records the connect;
  /// if WhatsApp doesn't open, the message is copied and nothing is recorded.
  Future<void> openWhatsApp(AlumniOutreachStudentModel student) async {
    final phone = student.targetWhatsAppPhone;
    if (phone.isEmpty) {
      AppSnackbar.warning('No Contact Number', 'No phone or WhatsApp number is registered for ${student.name}.');
      return;
    }
    if (busyIds.contains(student.studentId)) return;

    final messageText = getFormattedMessage(student);
    final fullNumber = phone.length == 10 ? '91$phone' : phone;
    final uri = Uri.parse('https://wa.me/$fullNumber?text=${Uri.encodeComponent(messageText)}');

    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      developer.log('openWhatsApp error: $e', name: 'AlumniOutreach');
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: messageText));
      AppSnackbar.warning(
        'WhatsApp Did Not Open',
        'The message for ${student.name} is copied. Paste it in WhatsApp, then tap Mark as done.',
      );
      return;
    }
    if (student.isPending) await markContacted(student, message: messageText);
  }

  /// Records that this alumnus was contacted and updates today's progress.
  Future<void> markContacted(AlumniOutreachStudentModel student, {String? message}) async {
    if (!busyIds.add(student.studentId)) return;
    try {
      final msg = message ?? getFormattedMessage(student);
      await _repository.markOutreachContacted(student.studentId, message: msg);

      final current = outreachData.value;
      if (current == null) return;
      final updatedStudents = [
        for (final s in current.students) s.studentId == student.studentId ? s.markedMessaged(msg) : s,
      ];
      final done = updatedStudents.where((s) => s.isMessaged).length;
      outreachData.value = AlumniDailyOutreachDataModel(
        groupName: current.groupName,
        date: current.date,
        targetDailyCount: current.targetDailyCount,
        contactedTodayCount: done,
        totalAlumniInGroup: current.totalAlumniInGroup,
        totalMessagedAlumni: current.totalMessagedAlumni + (student.isPending ? 1 : 0),
        messageTemplate: current.messageTemplate,
        students: updatedStudents,
      );
      historyLoaded.value = false; // the new connect belongs in the history

      if (done >= current.targetDailyCount && current.targetDailyCount > 0) {
        AppSnackbar.success(
          'Daily Goal Reached 🎉',
          'All ${current.targetDailyCount} alumni of the ${current.groupName} group are contacted today.',
        );
      } else {
        AppSnackbar.success('Marked as Done', '${student.name} is contacted ($done of ${current.targetDailyCount}).');
      }
    } catch (e) {
      developer.log('markContacted error: $e', name: 'AlumniOutreach');
      AppSnackbar.error('Not Saved', _message(e));
    } finally {
      busyIds.remove(student.studentId);
    }
  }

  /// Replaces this alumnus with another one of the group for today. The
  /// screen asks for confirmation first.
  Future<void> skipAlumnus(AlumniOutreachStudentModel student) async {
    if (!busyIds.add(student.studentId)) return;
    try {
      outreachData.value = await _repository.skipAndReplaceAlumnus(student.studentId);
      customMessageMap.remove(student.studentId);
      AppSnackbar.success('Alumnus Replaced', '${student.name} is skipped; another alumnus was added for today.');
    } catch (e) {
      developer.log('skipAlumnus error: $e', name: 'AlumniOutreach');
      AppSnackbar.error('Skip Failed', _message(e));
    } finally {
      busyIds.remove(student.studentId);
    }
  }

  /// Sends today's message to every pending alumnus through the office's
  /// linked WhatsApp session (admin only, like Birthday Wishes). Stops at the
  /// first alumnus the gateway did not send to, e.g. when WhatsApp went offline.
  Future<void> sendAllToday() async {
    if (isLeader.value || isSendingAll.value) return;
    final pending = (outreachData.value?.students ?? const <AlumniOutreachStudentModel>[])
        .where((s) => s.isPending)
        .toList();
    if (pending.isEmpty) {
      AppSnackbar.info('Nothing to Send', "Every alumnus of today's list is already messaged.");
      return;
    }
    isSendingAll.value = true;
    try {
      if (!await _isWhatsAppLinked()) {
        AppSnackbar.warning(
          'WhatsApp Not Connected',
          'Link the WhatsApp device in Birthday Wishes first, then try Send All again.',
        );
        return;
      }
      var sent = 0;
      var skippedNoNumber = 0;
      String? stoppedAt;
      for (var i = 0; i < pending.length; i++) {
        final s = pending[i];
        if (s.targetWhatsAppPhone.isEmpty) {
          skippedNoNumber++;
          continue;
        }
        busyIds.add(s.studentId);
        try {
          final result = await _repository.sendOutreachViaGateway(s.studentId, message: getFormattedMessage(s));
          if (result['gatewaySent'] != true) {
            stoppedAt = s.name;
            break;
          }
          sent++;
        } catch (e) {
          developer.log('sendAllToday error: $e', name: 'AlumniOutreach');
          stoppedAt = s.name;
          break;
        } finally {
          busyIds.remove(s.studentId);
        }
        if (i < pending.length - 1) await Future<void>.delayed(sendAllGap);
      }
      await loadDailyOutreach();
      historyLoaded.value = false;

      final extra = skippedNoNumber > 0 ? ' $skippedNoNumber had no number.' : '';
      if (stoppedAt != null) {
        AppSnackbar.warning(
          'Send All Stopped',
          'Sent to $sent. Could not send to $stoppedAt, so the rest were left for later.$extra',
        );
      } else if (sent > 0) {
        AppSnackbar.success('Messages Sent', 'Sent to $sent ${sent == 1 ? 'alumnus' : 'alumni'}.$extra');
      } else {
        AppSnackbar.warning('Nothing Sent', 'No pending alumnus has a WhatsApp number.');
      }
    } finally {
      isSendingAll.value = false;
    }
  }

  /// Whether the office's WhatsApp session is online, as Birthday Wishes
  /// decides it: the status call reports the linked phone.
  Future<bool> _isWhatsAppLinked() async {
    try {
      final repo = Get.isRegistered<BirthdayRepository>() ? Get.find<BirthdayRepository>() : BirthdayRepository();
      final res = await repo.getWhatsAppStatus();
      final user = res['user'];
      return user is Map && (user['phone']?.toString() ?? '').isNotEmpty;
    } catch (e) {
      developer.log('whatsapp status error: $e', name: 'AlumniOutreach');
      return false;
    }
  }

  /// This alumnus's entry in the synced phonebook, found by student (bank)
  /// code. Display only: a code that is missing, or shared by several rows,
  /// finds nothing rather than guessing. Never use it to act on a student.
  Future<PhonebookStudent?> findInPhonebook(AlumniOutreachStudentModel student) async {
    final code = PhonebookDatabaseService.normalizeBankCode(student.studentCode);
    if (code.isEmpty) return null;
    try {
      final rows = await PhonebookDatabaseService.instance.searchStudents(query: student.studentCode.trim());
      final matches = rows.where((r) => PhonebookDatabaseService.normalizeBankCode(r.bankCode ?? '') == code).toList();
      return matches.length == 1 ? matches.first : null;
    } catch (e) {
      developer.log('findInPhonebook error: $e', name: 'AlumniOutreach');
      return null;
    }
  }

  void copyMessage(AlumniOutreachStudentModel student) {
    Clipboard.setData(ClipboardData(text: getFormattedMessage(student)));
    AppSnackbar.success('Message Copied', 'The message for ${student.name} is copied.');
  }

  Future<void> callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      AppSnackbar.warning('No Phone Number', 'No valid phone number to call.');
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppSnackbar.warning('Cannot Place Call', 'The dialer could not be opened.');
    }
  }

  /// Saves the shared message template (admin only).
  Future<void> saveTemplate() async {
    if (isLeader.value) {
      AppSnackbar.info('Set by the Office', 'Leaders can change the message for one alumnus from their card.');
      return;
    }
    final newTemplate = templateController.text.trim();
    if (newTemplate.isEmpty) {
      AppSnackbar.warning('Empty Template', 'Please enter a message template.');
      return;
    }
    isSaving.value = true;
    try {
      await _repository.saveOutreachConfig(newTemplate, outreachData.value?.targetDailyCount ?? 5);
      AppSnackbar.success('Template Saved', 'Every leader\'s alumni message now starts from this template.');
    } catch (e) {
      developer.log('saveTemplate error: $e', name: 'AlumniOutreach');
      AppSnackbar.error('Not Saved', _message(e));
    } finally {
      isSaving.value = false;
    }
  }
}
