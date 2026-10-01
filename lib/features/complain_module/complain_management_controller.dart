import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/request/complaints/update_complaint_request.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';

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
    loadAll();
  }

  @override
  void onClose() {
    queryController.dispose();
    quickResolveNoteController.dispose();
    quickSolverController.dispose();
    super.onClose();
  }

  Future<void> loadAll() async {
    isSearching.value = true;
    try {
      searchedRoom.value = '';
      final all = await _repository.adminComplaints();
      searchedComplaints.assignAll(all);
      selectedComplaint.value =
          searchedComplaints.isNotEmpty ? searchedComplaints.first : null;
    } catch (e) {
      AppSnackbar.error('Load Failed', 'Could not load complaints: $e');
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> searchRoom(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      await loadAll();
      return;
    }

    isSearching.value = true;
    try {
      searchedRoom.value = clean.toUpperCase();
      final all = await _repository.adminComplaints(room: clean);
      searchedComplaints.assignAll(all);
      selectedComplaint.value =
          searchedComplaints.isNotEmpty ? searchedComplaints.first : null;
    } catch (e) {
      AppSnackbar.error('Search Failed', 'Could not load room history: $e');
    } finally {
      isSearching.value = false;
    }
  }

  void selectBlock(String block) {
    selectedBlock.value = block;
    if (block == 'All') {
      loadAll();
    } else {
      final prefix = block.split('-').first;
      searchRoom(prefix);
    }
  }

  Future<void> logOnSiteResolution(String complaintId) async {
    final note = quickResolveNoteController.text.trim();
    if (note.isEmpty) {
      AppSnackbar.warning('Input Required', 'Please enter a resolution note or inspection outcome.');
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
      AppSnackbar.success('Logged', 'On-site resolution saved for Room ${updated.room}.');
    } catch (e) {
      AppSnackbar.error('Error', 'Failed to save resolution: $e');
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
      AppSnackbar.success('Updated', 'Inspection note logged.');
    } catch (e) {
      AppSnackbar.error('Error', 'Failed to update note: $e');
    } finally {
      isSubmitting.value = false;
    }
  }
}
