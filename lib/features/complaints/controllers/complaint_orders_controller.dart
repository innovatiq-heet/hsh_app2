import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/responses/complaints/complaint_catalog.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/utils/app_snackbar.dart';

/// Complaints Desk (complain-solver / admin): the queue filtered on the
/// server by status, category and room, a page at a time.
class ComplainOrdersController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();

  final roomController = TextEditingController();
  final searchController = TextEditingController();

  final complaints = <ComplaintResponse>[].obs;
  final categories = <ComplaintCategory>[].obs;

  /// `null` means all statuses. The desk opens on the open queue.
  final statusFilter = Rxn<ComplaintStatus>(ComplaintStatus.open);
  final categoryFilter = Rxn<ComplaintCategory>();
  final roomFilter = ''.obs;

  /// What is typed in the room box; applied as [roomFilter] after a pause.
  final roomQuery = ''.obs;
  final searchQuery = ''.obs;

  final hasMore = false.obs;
  final isLoadingMore = false.obs;
  final updatingId = RxnString();

  int get totalCount => complaints.length;
  int get openCount => complaints.where((c) => c.status == ComplaintStatus.open).length;
  int get inProgressCount => complaints.where((c) => c.status == ComplaintStatus.inProgress).length;
  int get resolvedCount => complaints.where((c) => c.status == ComplaintStatus.resolved).length;
  int get closedCount => complaints.where((c) => c.status == ComplaintStatus.closed).length;

  /// Real-time client-side filtered list across room, student name, code, item, category and comments.
  List<ComplaintResponse> get filteredComplaints {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return complaints;
    return complaints.where((c) {
      final room = c.roomId.toLowerCase();
      final item = c.item.toLowerCase();
      final cat = c.category.toLowerCase();
      final comment = (c.comment ?? '').toLowerCase();
      final name = (c.student?.name ?? '').toLowerCase();
      final code = (c.student?.studentCode ?? '').toLowerCase();
      final id = c.id.toLowerCase();
      return room.contains(q) ||
          item.contains(q) ||
          cat.contains(q) ||
          comment.contains(q) ||
          name.contains(q) ||
          code.contains(q) ||
          id.contains(q);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    debounce<String>(roomQuery, searchRoom, time: const Duration(milliseconds: 500));
    load();
    _loadCategories();
  }

  @override
  void onClose() {
    roomController.dispose();
    searchController.dispose();
    super.onClose();
  }

  /// The filter offers only the categories this solver works on (the API
  /// returns only their complaints anyway).
  Future<void> _loadCategories() async {
    try {
      final all = await _repository.categories();
      categories.assignAll(ComplaintCategory.limitTo(all, await _repository.assignedCategoryIds()));
    } catch (_) {
      // The category filter is optional; the queue still works without it.
    }
  }

  Future<List<ComplaintResponse>> _page(int offset) => _repository.adminComplaints(
        status: statusFilter.value,
        categoryId: categoryFilter.value?.id,
        roomId: roomFilter.value,
        offset: offset,
      );

  Future<void> load({bool showLoading = true}) => guard(() async {
        final page = await _page(0);
        complaints.assignAll(page);
        hasMore.value = page.length == ComplaintsRepository.pageSize;
      }, showLoading: showLoading);

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final page = await _page(complaints.length);
      complaints.addAll(page);
      hasMore.value = page.length == ComplaintsRepository.pageSize;
    } on ApiException catch (e) {
      AppSnackbar.error('Could not load more', e.message);
    } catch (_) {
      AppSnackbar.error('Could not load more', 'Something went wrong, try again');
    } finally {
      isLoadingMore.value = false;
    }
  }

  void setStatusFilter(ComplaintStatus? status) {
    if (statusFilter.value == status) return;
    statusFilter.value = status;
    load();
  }

  void setCategoryFilter(ComplaintCategory? category) {
    if (categoryFilter.value?.id == category?.id) return;
    categoryFilter.value = category;
    load();
  }

  void onSearchChanged(String val) {
    searchQuery.value = val;
    // Also sync with backend room query if numeric
    final clean = val.trim();
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      roomQuery.value = clean;
    } else if (roomFilter.value.isNotEmpty) {
      roomFilter.value = '';
      load();
    }
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    roomController.clear();
    roomQuery.value = '';
    if (roomFilter.value.isNotEmpty) {
      roomFilter.value = '';
      load();
    }
  }

  void resetAllFilters() {
    statusFilter.value = null;
    categoryFilter.value = null;
    clearSearch();
    load();
  }

  /// Rooms are matched exactly by the API (e.g. "101").
  void searchRoom(String room) {
    final clean = room.trim();
    if (clean == roomFilter.value) return;
    roomFilter.value = clean;
    load();
  }

  void clearRoom() {
    roomController.clear();
    roomQuery.value = '';
    searchRoom('');
  }

  bool get hasFilters =>
      statusFilter.value != null ||
      categoryFilter.value != null ||
      searchQuery.value.isNotEmpty ||
      roomFilter.value.isNotEmpty;

  /// Any status may move to any other; the row is replaced with the
  /// server's copy.
  Future<void> changeStatus(ComplaintResponse complaint, ComplaintStatus status) async {
    if (complaint.status == status || updatingId.value != null) return;
    updatingId.value = complaint.id;
    try {
      final updated = await _repository.updateStatus(complaint.id, status);
      final index = complaints.indexWhere((c) => c.id == complaint.id);
      if (index != -1) complaints[index] = updated;
      AppSnackbar.success(
        'Status updated',
        'Complaint #${complaint.id} is now ${status.staffLabel}.',
      );
    } on ApiException catch (e) {
      AppSnackbar.error('Update failed', e.message);
    } catch (_) {
      AppSnackbar.error('Update failed', 'Something went wrong, try again');
    } finally {
      updatingId.value = null;
    }
  }
}
