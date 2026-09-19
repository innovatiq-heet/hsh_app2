import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/complaint_status.dart';
import '../../common_enums/user_role.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/request/complaints/update_complaint_request.dart';
import '../../network/responses/complaints/complaint_response.dart';
import '../../storage/session_store.dart';

class ComplainOrdersController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();

  final complaints = <ComplaintResponse>[].obs;
  final Rxn<ComplaintStatus> statusFilter = Rxn<ComplaintStatus>();
  final RxnString categoryFilter = RxnString();
  final searchQuery = ''.obs;
  final advancingComplaintId = RxnString();
  final isAdmin = false.obs;

  int get pendingCount =>
      complaints.where((c) => c.status == ComplaintStatus.pending).length;
  int get reviewedCount =>
      complaints.where((c) => c.status == ComplaintStatus.reviewed).length;
  int get resolvedCount =>
      complaints.where((c) => c.status == ComplaintStatus.resolved).length;
  int get activeCount =>
      complaints.where((c) => c.status != ComplaintStatus.resolved).length;

  int countForStatus(ComplaintStatus? status) {
    if (status == null) return complaints.length;
    return complaints.where((c) => c.status == status).length;
  }

  int countForCategory(String? category) {
    if (category == null) return complaints.length;
    return complaints.where((c) => c.category.toLowerCase() == category.toLowerCase()).length;
  }

  List<ComplaintResponse> get filtered {
    return complaints.where((c) {
      if (statusFilter.value != null && c.status != statusFilter.value) {
        return false;
      }
      if (categoryFilter.value != null &&
          categoryFilter.value!.isNotEmpty &&
          c.category.toLowerCase() != categoryFilter.value!.toLowerCase()) {
        return false;
      }
      final query = searchQuery.value.trim().toLowerCase();
      if (query.isEmpty) return true;
      final cid = c.id.toLowerCase();
      return cid.contains(query) ||
          c.studentAadhar.toLowerCase().contains(query) ||
          c.studentName.toLowerCase().contains(query) ||
          c.room.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query) ||
          c.title.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    _checkRole();
    load();
  }

  Future<void> _checkRole() async {
    final role = await SessionStore.instance.role;
    isAdmin.value = role == UserRole.admin;
  }

  Future<void> load() => guard(() async {
    complaints.assignAll(await _repository.adminComplaints());
  });

  Future<void> markReviewed(String complaintId, {String? reviewNote}) async {
    advancingComplaintId.value = complaintId;
    try {
      final updated = await _repository.updateComplaint(
        complaintId,
        UpdateComplaintRequest(
          status: ComplaintStatus.reviewed,
          review: reviewNote,
        ),
      );
      final idx = complaints.indexWhere((c) => c.id == complaintId);
      if (idx != -1) complaints[idx] = updated;
      Get.snackbar('Success', 'Complaint #$complaintId moved to Under Review.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update complaint: $e');
    } finally {
      advancingComplaintId.value = null;
    }
  }

  Future<void> markResolved(String complaintId, {required String feedback}) async {
    advancingComplaintId.value = complaintId;
    try {
      final updated = await _repository.updateComplaint(
        complaintId,
        UpdateComplaintRequest(
          status: ComplaintStatus.resolved,
          response: feedback,
        ),
      );
      final idx = complaints.indexWhere((c) => c.id == complaintId);
      if (idx != -1) complaints[idx] = updated;
      Get.snackbar('Resolved', 'Complaint #$complaintId has been marked as resolved.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to resolve complaint: $e');
    } finally {
      advancingComplaintId.value = null;
    }
  }

  Future<void> deleteComplaint(String complaintId) async {
    advancingComplaintId.value = complaintId;
    try {
      await _repository.deleteComplaint(complaintId);
      complaints.removeWhere((c) => c.id == complaintId);
      Get.snackbar('Deleted', 'Complaint #$complaintId has been removed.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete complaint: $e');
    } finally {
      advancingComplaintId.value = null;
    }
  }
}
