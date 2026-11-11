import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/broadcasts/broadcasts_repository.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/utils/student_picker_host.dart';
import 'broadcast_admin_gate.dart';

/// A random UUID v4, used as `client_request_id` so a retried send is never
/// delivered twice.
String newClientRequestId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Admin → Broadcast → New: message, audience (tags ∪ individual students),
/// live reach count, send.
class BroadcastComposeController extends GetxController
    with BroadcastAdminGate, StudentPickerHost {
  BroadcastComposeController({
    BroadcastsRepository? repository,
    TagsRepository? tagsRepository,
    ScreenTimeRepository? screenTimeRepository,
    this.previewDebounce = const Duration(milliseconds: 400),
  })  : _repo = repository ?? Get.find<BroadcastsRepository>(),
        _tagsRepo = tagsRepository ?? Get.find<TagsRepository>(),
        _screenTimeRepo = screenTimeRepository;

  static const maxTitle = 100;
  static const maxMessage = 2000;

  final BroadcastsRepository _repo;
  final TagsRepository _tagsRepo;
  final ScreenTimeRepository? _screenTimeRepo;
  final Duration previewDebounce;

  /// Individual picks: residents only (alumni don't get broadcasts).
  @override
  late final StudentPickerSource studentSource =
      StudentPickerSource(tags: _tagsRepo, screenTime: _screenTimeRepo);

  @override
  void onStudentsChanged() => _schedulePreview();

  final titleController = TextEditingController();
  final messageController = TextEditingController();
  final title = ''.obs;
  final message = ''.obs;

  final tags = <StudentTag>[].obs;
  final isTagsLoading = false.obs;
  final selectedTagIds = <int>{}.obs;

  final preview = BroadcastPreview.empty.obs;
  final isPreviewLoading = false.obs;
  final previewError = RxnString();

  final isSending = false.obs;

  /// Fixed for this screen, so every retry of the same send is deduplicated
  /// by the server.
  final String clientRequestId = newClientRequestId();

  Timer? _debounce;
  int _previewSeq = 0;

  @override
  void onInit() {
    super.onInit();
    titleController.addListener(() => title.value = titleController.text);
    messageController.addListener(() => message.value = messageController.text);
    _start();
  }

  Future<void> _start() async {
    if (await ensureAdmin()) await loadTags();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    titleController.dispose();
    messageController.dispose();
    super.onClose();
  }

  // --- validation ---

  String get trimmedTitle => title.value.trim();
  String get trimmedMessage => message.value.trim();

  bool get titleValid => trimmedTitle.isNotEmpty && trimmedTitle.length <= maxTitle;
  bool get messageValid => trimmedMessage.isNotEmpty && trimmedMessage.length <= maxMessage;
  bool get hasAudience => selectedTagIds.isNotEmpty || selectedStudents.isNotEmpty;

  bool get canSend =>
      titleValid &&
      messageValid &&
      hasAudience &&
      !isPreviewLoading.value &&
      previewError.value == null &&
      preview.value.recipientCount > 0 &&
      !isSending.value;

  // --- audience ---

  Future<void> loadTags() async {
    isTagsLoading.value = true;
    try {
      tags.assignAll(dedupeTags(await _tagsRepo.getTags()));
    } catch (_) {
      // Individual picks still work without tags.
    } finally {
      isTagsLoading.value = false;
    }
  }

  void toggleTag(int tagId) {
    if (!selectedTagIds.remove(tagId)) selectedTagIds.add(tagId);
    _schedulePreview();
  }

  // --- reach preview ---

  void _schedulePreview() {
    _debounce?.cancel();
    previewError.value = null;
    if (!hasAudience) {
      _previewSeq++; // drop any reply still in flight
      preview.value = BroadcastPreview.empty;
      isPreviewLoading.value = false;
      return;
    }
    isPreviewLoading.value = true;
    _debounce = Timer(previewDebounce, refreshPreview);
  }

  /// Asks the server how many students the current audience reaches. Only
  /// the newest reply is kept.
  Future<void> refreshPreview() async {
    if (!hasAudience) return;
    final seq = ++_previewSeq;
    isPreviewLoading.value = true;
    previewError.value = null;
    try {
      final result = await _repo.preview(
        tagIds: _tagIds,
        studentIds: _studentIds,
      );
      if (seq != _previewSeq) return;
      preview.value = result;
    } on ApiException catch (e) {
      if (seq != _previewSeq) return;
      previewError.value = e.message;
    } catch (_) {
      if (seq != _previewSeq) return;
      previewError.value = "Couldn't count recipients";
    } finally {
      if (seq == _previewSeq) isPreviewLoading.value = false;
    }
  }

  List<int> get _tagIds => selectedTagIds.toList()..sort();
  List<int> get _studentIds => [for (final s in selectedStudents) s.id];

  // --- send ---

  /// Sends the broadcast. Returns it on success, or null after showing the
  /// server's message; the form keeps its contents for a retry, which reuses
  /// [clientRequestId].
  Future<Broadcast?> send() async {
    if (!canSend) return null;
    isSending.value = true;
    try {
      return await _repo.send(
        clientRequestId: clientRequestId,
        title: trimmedTitle,
        message: trimmedMessage,
        tagIds: _tagIds,
        studentIds: _studentIds,
      );
    } on ApiException catch (e) {
      AppSnackbar.error('Broadcast Not Sent', e.message);
      return null;
    } catch (_) {
      AppSnackbar.error('Broadcast Not Sent', 'Something went wrong, try again.');
      return null;
    } finally {
      isSending.value = false;
    }
  }
}
