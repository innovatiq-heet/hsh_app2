import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../../core/utils/app_snackbar.dart';

/// Admin → Student Tags: the roles and labels (Regular, Karyakarta, Wing
/// Leader ...) that can be put on students. Create, rename, delete, and
/// open a tag to assign it.
class StudentTagsController extends GetxController with LoadStateMixin {
  StudentTagsController({TagsRepository? tagsRepo})
      : _tagsRepo = tagsRepo ??
            (Get.isRegistered<TagsRepository>()
                ? Get.find<TagsRepository>()
                : Get.put(TagsRepository()));

  final TagsRepository _tagsRepo;

  final tags = <StudentTag>[].obs;

  /// Tags with a delete request in flight.
  final busyIds = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        tags.assignAll(await _tagsRepo.getTags());
      }, showLoading: showLoading);

  Future<bool> createTag({
    required String name,
    required String color,
    String? description,
  }) async {
    try {
      final newTag = await _tagsRepo.createTag(
        name: name,
        color: color,
        description: description,
      );
      tags.add(newTag);
      AppSnackbar.success('Tag Created', 'Created tag "${newTag.name}".');
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Create Tag Failed', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Create Tag Failed', 'Something went wrong, try again.');
      return false;
    }
  }

  Future<bool> updateTag({
    required int id,
    required String name,
    required String color,
    String? description,
  }) async {
    try {
      final updated = await _tagsRepo.updateTag(
        id: id,
        name: name,
        color: color,
        description: description,
      );
      final idx = tags.indexWhere((t) => t.id == id);
      if (idx != -1) {
        tags[idx] = updated;
      }
      AppSnackbar.success('Tag Updated', _tagsRepo.lastWrite.addTo('Tag "${updated.name}" updated successfully.'));
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Update Failed', e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Update Failed', 'Something went wrong, try again.');
      return false;
    }
  }

  Future<void> deleteTag(StudentTag tag) async {
    if (tag.isSystem) {
      AppSnackbar.warning('System Tag', 'System tags cannot be deleted.');
      return;
    }
    if (busyIds.contains(tag.id)) return;
    busyIds.add(tag.id);
    try {
      final result = await _tagsRepo.deleteTag(tag.id);
      tags.removeWhere((t) => t.id == tag.id);
      AppSnackbar.success('Tag Deleted', result.addTo('Tag "${tag.name}" was removed.'));
    } on ApiException catch (e) {
      AppSnackbar.error('Delete Failed', e.message);
    } catch (_) {
      AppSnackbar.error('Delete Failed', 'Something went wrong, try again.');
    } finally {
      busyIds.remove(tag.id);
    }
  }
}
