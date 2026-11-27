import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/broadcasts/broadcasts_repository.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/image_type.dart';
import '../../shared/utils/student_picker_host.dart';
import '../utils/tag_members.dart';
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

  /// Individual picks: residents and alumni can both be selected.
  @override
  bool get includeAlumniInPicker => true;

  @override
  late final StudentPickerSource studentSource =
      StudentPickerSource(tags: _tagsRepo, screenTime: _screenTimeRepo);

  @override
  void onStudentsChanged() {
    if (selectedStudents.isNotEmpty) groupAudiencePreset.value = null;
    _schedulePreview();
  }

  /// Leader group context (only populated when [isLeaderView] is true).
  final leaderGroupName = ''.obs;
  final leaderResidentsCount = 0.obs;
  final leaderAlumniCount = 0.obs;
  final leaderTotalCount = 0.obs;
  final leaderWhatsappConnected = false.obs;
  final leaderHasLinkedWhatsApp = false.obs;
  final leaderLinkedPhone = RxnString();

  /// Quick house audience preset for leaders: 'residents', 'alumni', 'all', or null.
  final RxnString groupAudiencePreset = RxnString();

  final titleController = TextEditingController();
  final messageController = TextEditingController();
  final title = ''.obs;
  final message = ''.obs;

  final tags = <StudentTag>[].obs;
  final isTagsLoading = false.obs;
  final selectedTagIds = <int>{}.obs;

  /// Who in the selected tags gets it: current students, alumni, or both.
  /// Must be chosen (null until then) before a broadcast with tags is sent.
  final tagScope = Rxn<TagMemberScope>();

  /// The selected tags' members, split current / alumni (for the counts and
  /// for sending to one group only).
  final tagMembers = TagMembers.empty.obs;
  final isMembersLoading = false.obs;
  final membersError = RxnString();

  /// Every student with their tags (`GET /students?all=true`), loaded once.
  List<Map<String, dynamic>>? _studentRows;

  /// The server takes at most this many individual students per broadcast.
  static const maxStudentIds = 500;

  final preview = BroadcastPreview.empty.obs;
  final isPreviewLoading = false.obs;
  final previewError = RxnString();

  final isSending = false.obs;

  /// Optional picture. It uploads as soon as it is chosen, so [send] only
  /// carries the returned id (and a retried send never uploads twice).
  final image = Rxn<File>();
  final uploadedImage = Rxn<BroadcastImageUpload>();
  final isImageUploading = false.obs;
  int _imageSeq = 0;

  /// Delivery channel: 'both' (app + whatsapp), 'app' (in-app only), or 'whatsapp' (whatsapp only).
  final selectedChannel = BroadcastChannel.both.obs;

  void setChannel(BroadcastChannel channel) {
    selectedChannel.value = channel;
  }

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
    if (await ensureAdminOrLeader()) {
      if (isLeaderView.value) {
        await Future.wait([loadLeaderSummary(), loadStudents(), loadTags()]);
      } else {
        loadStudents(); // in the background: the picker is ready when opened
        await loadTags();
      }
    }
  }

  Future<void> loadLeaderSummary() async {
    if (!isLeaderView.value) return;
    try {
      final summary = await _repo.leaderAudienceSummary();
      leaderGroupName.value = (summary['groupName'] ?? '').toString().trim();
      leaderResidentsCount.value = int.tryParse('${summary['residentsCount'] ?? 0}') ?? 0;
      leaderAlumniCount.value = int.tryParse('${summary['alumniCount'] ?? 0}') ?? 0;
      leaderTotalCount.value = int.tryParse('${summary['totalCount'] ?? 0}') ?? 0;
      leaderWhatsappConnected.value = summary['whatsappConnected'] == true;
      leaderHasLinkedWhatsApp.value = summary['hasLinkedAccount'] == true;
      final ph = summary['linkedPhone']?.toString().trim();
      leaderLinkedPhone.value = (ph != null && ph.isNotEmpty) ? ph : null;
    } catch (_) {
      // Fall back gracefully if summary endpoint is temporarily unavailable.
    }
  }

  @override
  Future<void> loadStudents({bool force = false}) async {
    if (!isLeaderView.value) {
      return super.loadStudents(force: force);
    }
    if (students.isNotEmpty && !force) return;
    isStudentsLoading.value = true;
    studentsError.value = null;
    try {
      final rows = await _repo.leaderGroupMembers();
      students.assignAll([
        for (final r in rows)
          if (studentIdOf(r) != null)
            PickableStudent(
              id: studentIdOf(r)!,
              name: (r['name'] ?? '').toString(),
              room: (r['room'] ?? '').toString(),
              isAlumni: r['is_alumni'] == true,
            ),
      ]);
    } on ApiException catch (e) {
      studentsError.value = e.message;
    } catch (_) {
      studentsError.value = 'Could not load group members.';
    } finally {
      isStudentsLoading.value = false;
    }
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

  /// Title is optional: valid if empty or within limit.
  bool get titleValid => trimmedTitle.length <= maxTitle;
  bool get messageValid => trimmedMessage.isNotEmpty && trimmedMessage.length <= maxMessage;
  bool get hasPresetAudience => isLeaderView.value && groupAudiencePreset.value != null;
  bool get hasAudience => hasPresetAudience || selectedTagIds.isNotEmpty || selectedStudents.isNotEmpty;

  bool get canSend =>
      titleValid &&
      messageValid &&
      hasAudience &&
      (hasPresetAudience || selectedTagIds.isEmpty || tagScope.value != null) &&
      !isPreviewLoading.value &&
      previewError.value == null &&
      preview.value.recipientCount > 0 &&
      !isImageUploading.value &&
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

  /// Reloads the tags and unselects any that no longer exist (it would
  /// otherwise stay in the audience with nothing on screen to remove it).
  Future<void> refreshTags() async {
    await loadTags();
    final known = {for (final t in tags) t.id};
    for (final id in selectedTagIds.where((id) => !known.contains(id)).toList()) {
      toggleTag(id);
    }
  }

  void setGroupAudiencePreset(String? preset) {
    if (!isLeaderView.value) return;
    if (groupAudiencePreset.value == preset) {
      groupAudiencePreset.value = null;
    } else {
      groupAudiencePreset.value = preset;
      if (preset != null) {
        selectedTagIds.clear();
        tagScope.value = null;
        tagMembers.value = TagMembers.empty;
        selectedStudents.clear();
      }
    }
    _schedulePreview();
  }

  void toggleTag(int tagId) {
    if (!selectedTagIds.remove(tagId)) {
      selectedTagIds.add(tagId);
      groupAudiencePreset.value = null;
    }
    if (selectedTagIds.isEmpty) tagScope.value = null;
    _refreshMembers();
    _schedulePreview();
  }

  void setTagScope(TagMemberScope scope) {
    tagScope.value = scope;
    _schedulePreview();
  }

  /// Recounts the selected tags' members, loading the student list once.
  Future<void> _refreshMembers() async {
    if (selectedTagIds.isEmpty) {
      tagMembers.value = TagMembers.empty;
      return;
    }
    if (_studentRows == null) {
      isMembersLoading.value = true;
      membersError.value = null;
      try {
        _studentRows = await _tagsRepo.getStudentsForAssignment();
      } catch (_) {
        membersError.value = "Couldn't load the tags' students";
      } finally {
        isMembersLoading.value = false;
      }
    }
    final rows = _studentRows;
    tagMembers.value = rows == null ? TagMembers.empty : TagMembers.of(rows, selectedTagIds.toSet());
    // A choice of one group depends on these numbers.
    if (tagScope.value != null && tagScope.value != TagMemberScope.all) _schedulePreview();
  }

  /// What is sent: the tags themselves for everyone in them, or, for one
  /// group only, that group's students (numeric students.id) plus individual
  /// picks. Null with a reason when it can't be worked out yet.
  ({List<int> tagIds, List<int> studentIds})? _audience() {
    if (hasPresetAudience) {
      return (tagIds: const <int>[], studentIds: const <int>[]);
    }
    final scope = tagScope.value;
    if (selectedTagIds.isEmpty || scope == null || scope == TagMemberScope.all) {
      return (tagIds: _tagIds, studentIds: _studentIds);
    }
    if (_studentRows == null) return null;
    final ids = <int>{...tagMembers.value.idsFor(scope), ..._studentIds}.toList()..sort();
    return (tagIds: const <int>[], studentIds: ids);
  }

  // --- picture ---

  /// `imageQuality` makes image_picker re-encode to JPEG, which also turns
  /// iPhone HEIC photos into something the API accepts.
  Future<void> pickImage([ImageSource source = ImageSource.gallery]) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;
      await attachImage(File(picked.path));
    } catch (e) {
      AppSnackbar.error('Picture', 'Could not select picture: $e');
    }
  }

  /// Checks [file] the way the API will (JPEG / PNG / WebP by content, at most
  /// 5 MB), then uploads it. A newer pick or [removeImage] wins over a slower
  /// upload still in flight.
  Future<void> attachImage(File file) async {
    final error = await validateImage(file);
    if (error != null) {
      AppSnackbar.warning('Picture not added', error);
      return;
    }
    final seq = ++_imageSeq;
    image.value = file;
    uploadedImage.value = null;
    isImageUploading.value = true;
    try {
      final uploaded = await _repo.uploadImage(file, isLeader: isLeaderView.value);
      if (seq != _imageSeq) return;
      uploadedImage.value = uploaded;
    } on ApiException catch (e) {
      if (seq != _imageSeq) return;
      image.value = null;
      AppSnackbar.error('Picture Not Uploaded', e.message);
    } catch (_) {
      if (seq != _imageSeq) return;
      image.value = null;
      AppSnackbar.error('Picture Not Uploaded', 'Something went wrong, try again.');
    } finally {
      if (seq == _imageSeq) isImageUploading.value = false;
    }
  }

  void removeImage() {
    _imageSeq++; // drop any upload still in flight
    image.value = null;
    uploadedImage.value = null;
    isImageUploading.value = false;
  }

  /// Why the API would reject [file], or `null` if it is fine.
  static Future<String?> validateImage(File file) async {
    if (await file.length() > ImageType.maxUploadBytes) {
      return 'Picture must be 5 MB or smaller.';
    }
    final raf = await file.open();
    try {
      if (ImageType.sniffMimeType(await raf.read(16)) == null) {
        return 'Please choose a JPEG, PNG or WebP picture.';
      }
    } finally {
      await raf.close();
    }
    return null;
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
    final audience = _audience();
    if (audience == null) {
      // Still loading the tags' students: _refreshMembers previews again when done.
      if (isMembersLoading.value) return;
      previewError.value = membersError.value ?? "Couldn't load the tags' students";
      isPreviewLoading.value = false;
      return;
    }
    if (audience.studentIds.length > maxStudentIds) {
      previewError.value = 'That is ${audience.studentIds.length} students; one broadcast can reach at most '
          '$maxStudentIds picked one by one. Choose "Current & alumni" or fewer tags.';
      isPreviewLoading.value = false;
      return;
    }
    final preset = hasPresetAudience ? groupAudiencePreset.value : null;
    if (preset == null && audience.tagIds.isEmpty && audience.studentIds.isEmpty) {
      preview.value = BroadcastPreview.empty;
      isPreviewLoading.value = false;
      return;
    }
    try {
      final result = await _repo.preview(
        tagIds: audience.tagIds,
        studentIds: audience.studentIds,
        audiencePreset: preset,
        isLeader: isLeaderView.value,
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
    final audience = _audience();
    if (audience == null) return null;
    isSending.value = true;
    try {
      return await _repo.send(
        clientRequestId: clientRequestId,
        title: trimmedTitle.isNotEmpty ? trimmedTitle : null,
        message: trimmedMessage,
        imageId: uploadedImage.value?.imageId,
        channels: selectedChannel.value.name,
        tagIds: audience.tagIds,
        studentIds: audience.studentIds,
        audiencePreset: hasPresetAudience ? groupAudiencePreset.value : null,
        isLeader: isLeaderView.value,
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
