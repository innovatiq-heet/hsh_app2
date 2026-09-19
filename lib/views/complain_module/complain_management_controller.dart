import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/complaint_status.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/request/complaints/update_complaint_request.dart';
import '../../network/responses/complaints/complaint_response.dart';

class ComplainManagementController extends GetxController {
  final ComplaintsRepository _repository = Get.find();

  final formKey = GlobalKey<FormState>();
  final queryController = TextEditingController();
  final quickResolveNoteController = TextEditingController();
  final quickSolverController = TextEditingController();

  final isSearching = false.obs;
  final isSubmitting = false.obs;
  final selectedBlock = 'All'.obs;
  final searchedRoom = ''.obs;
  final searchedComplaints = <ComplaintResponse>[].obs;
  final selectedComplaint = Rxn<ComplaintResponse>();

  static const blocks = ['All', 'A-Block', 'B-Block', 'C-Block'];

  int get roomActiveCount =>
      searchedComplaints.where((c) => c.status != ComplaintStatus.resolved).length;
  int get roomResolvedCount =>
      searchedComplaints.where((c) => c.status == ComplaintStatus.resolved).length;

  @override
  void onInit() {
    super.onInit();
    // Default search with room A-204 for immediate rich preview
    searchRoom('A-204');
  }

  @override
  void onClose() {
    queryController.dispose();
    quickResolveNoteController.dispose();
    quickSolverController.dispose();
    super.onClose();
  }

  Future<void> searchRoom(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    isSearching.value = true;
    try {
      searchedRoom.value = clean.toUpperCase();
      final all = await _repository.adminComplaints(room: clean);
      searchedComplaints.assignAll(all);
      if (searchedComplaints.isNotEmpty) {
        selectedComplaint.value = searchedComplaints.first;
      } else {
        selectedComplaint.value = null;
      }
    } catch (e) {
      Get.snackbar('Search Failed', 'Could not load room history: $e');
    } finally {
      isSearching.value = false;
    }
  }

  void selectBlock(String block) {
    selectedBlock.value = block;
    if (block == 'All') {
      searchRoom('A-204');
    } else {
      final prefix = block.split('-').first;
      searchRoom(prefix);
    }
  }

  Future<void> logOnSiteResolution(String complaintId) async {
    final note = quickResolveNoteController.text.trim();
    if (note.isEmpty) {
      Get.snackbar('Input Required', 'Please enter a resolution note or inspection outcome.');
      return;
    }

    isSubmitting.value = true;
    try {
      final updated = await _repository.updateComplaint(
        complaintId,
        UpdateComplaintRequest(
          status: ComplaintStatus.resolved,
          response: note,
          user: quickSolverController.text.trim().isNotEmpty
              ? quickSolverController.text.trim()
              : 'Maintenance Staff',
        ),
      );

      final idx = searchedComplaints.indexWhere((c) => c.id == complaintId);
      if (idx != -1) searchedComplaints[idx] = updated;
      selectedComplaint.value = updated;
      quickResolveNoteController.clear();
      Get.snackbar('Logged', 'On-site resolution saved for Room ${updated.room}.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to save resolution: $e');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> updateReviewNote(String complaintId, String reviewNote) async {
    isSubmitting.value = true;
    try {
      final updated = await _repository.updateComplaint(
        complaintId,
        UpdateComplaintRequest(
          status: ComplaintStatus.reviewed,
          review: reviewNote,
        ),
      );

      final idx = searchedComplaints.indexWhere((c) => c.id == complaintId);
      if (idx != -1) searchedComplaints[idx] = updated;
      selectedComplaint.value = updated;
      Get.snackbar('Updated', 'Inspection note logged.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update note: $e');
    } finally {
      isSubmitting.value = false;
    }
  }
}
