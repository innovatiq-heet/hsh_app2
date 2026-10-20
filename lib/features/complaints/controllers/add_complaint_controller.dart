import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/auth/user_session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/authentication/auth_repository.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/request/complaints/submit_complaint_request.dart';
import '../../../core/network/responses/complaints/complaint_catalog.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/image_type.dart';

/// New complaint: category → item → optional comment and photo. The room is
/// the student's own (from `/auth/me`) and cannot be edited.
class AddComplaintController extends GetxController {
  final ComplaintsRepository _repository = Get.find();
  final AuthRepository _authRepository = Get.find();
  final SessionStore _session = Get.find();

  static const maxCommentLength = 2000;

  final commentController = TextEditingController();

  final categories = <ComplaintCategory>[].obs;
  final items = <ComplaintItem>[].obs;
  final selectedCategory = Rxn<ComplaintCategory>();
  final selectedItem = Rxn<ComplaintItem>();
  final image = Rxn<File>();
  final room = ''.obs;

  final isLoading = true.obs;
  final loadError = ''.obs;
  final isLoadingItems = false.obs;
  final itemsError = ''.obs;
  final isSaving = false.obs;

  /// Alumni have room "N/A" and may not file complaints.
  bool get hasRoom =>
      room.value.isNotEmpty && !UserSession.isAlumniRoomOrId(room: room.value);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    commentController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = '';
    try {
      await Future.wait([_loadCategories(), _loadRoom()]);
    } on ApiException catch (e) {
      loadError.value = e.message;
    } catch (_) {
      loadError.value = 'Something went wrong, try again';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadCategories() async {
    categories.assignAll(await _repository.categories());
  }

  /// The API only accepts the room on the student's record, so it is read
  /// from `/auth/me` (`room_number`), falling back to the cached session.
  Future<void> _loadRoom() async {
    final token = _session.currentToken ?? await _session.token;
    final me = token == null || token.isEmpty
        ? null
        : await _authRepository.checkSession(token);
    room.value = (me?.room.isNotEmpty == true ? me!.room : null) ??
        _session.session?.room ??
        '';
  }

  Future<void> selectCategory(ComplaintCategory category) async {
    if (selectedCategory.value?.id == category.id) return;
    selectedCategory.value = category;
    selectedItem.value = null;
    items.clear();
    await loadItems();
  }

  Future<void> loadItems() async {
    final category = selectedCategory.value;
    if (category == null) return;
    isLoadingItems.value = true;
    itemsError.value = '';
    try {
      final fetched = await _repository.items(category.id);
      // Ignore a late response for a category the student already left.
      if (selectedCategory.value?.id == category.id) items.assignAll(fetched);
    } on ApiException catch (e) {
      itemsError.value = e.message;
    } catch (_) {
      itemsError.value = 'Something went wrong, try again';
    } finally {
      isLoadingItems.value = false;
    }
  }

  void selectItem(ComplaintItem item) => selectedItem.value = item;

  /// `imageQuality` makes image_picker re-encode to JPEG, which also turns
  /// iPhone HEIC photos into something the API accepts.
  Future<void> pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final error = await validateImage(file);
    if (error != null) {
      AppSnackbar.warning('Photo not added', error);
      return;
    }
    image.value = file;
  }

  /// Why the API would reject [file], or `null` if it is fine.
  static Future<String?> validateImage(File file) async {
    if (await file.length() > ImageType.maxUploadBytes) {
      return 'Photo must be 5 MB or smaller.';
    }
    final raf = await file.open();
    try {
      if (ImageType.sniffMimeType(await raf.read(16)) == null) {
        return 'Please choose a JPEG, PNG or WebP photo.';
      }
    } finally {
      await raf.close();
    }
    return null;
  }

  void removeImage() => image.value = null;

  Future<bool> submit() async {
    final category = selectedCategory.value;
    final item = selectedItem.value;
    if (!hasRoom) {
      AppSnackbar.error(
        'Cannot submit',
        'Only students with an assigned room can submit complaints.',
      );
      return false;
    }
    if (category == null) {
      AppSnackbar.warning('Missing category', 'Please select a category.');
      return false;
    }
    if (item == null) {
      AppSnackbar.warning('Missing item', 'Please select what needs fixing.');
      return false;
    }

    isSaving.value = true;
    try {
      await _repository.submit(
        SubmitComplaintRequest(
          roomId: room.value,
          categoryId: category.id,
          itemId: item.id,
          comment: commentController.text,
          image: image.value,
        ),
      );
      AppSnackbar.success(
        'Complaint submitted',
        'The maintenance team will pick it up soon.',
      );
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Submission failed', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Submission failed', 'Something went wrong, try again');
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
