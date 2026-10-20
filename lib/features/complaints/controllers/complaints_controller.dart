import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/storage/session_store.dart';

/// "My Complaints" for the signed-in student, newest first.
class ComplaintsController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();

  /// The API caps a page at 200; a student never files that many.
  static const _limit = 200;

  final complaints = <ComplaintResponse>[].obs;

  /// Alumni (room "N/A") get 403 from the API, so the button is hidden.
  bool get canSubmit => !(Get.find<SessionStore>().session?.isAlumni ?? false);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        complaints.assignAll(await _repository.myComplaints(limit: _limit));
      }, showLoading: showLoading);
}
