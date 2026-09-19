import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../abstracts/mixins/paginated_list_mixin.dart';
import '../../network/repository/operator/operator_repository.dart';
import '../../network/responses/operator/operator_responses.dart';

class OperatorDirectoryController extends GetxController
    with PaginatedListMixin<StudentDirectoryItem> {
  final OperatorRepository _repository = Get.find();

  final searchController = TextEditingController();
  String _query = '';

  @override
  void onInit() {
    super.onInit();
    loadInitial();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  @override
  Future<List<StudentDirectoryItem>> fetchPage({
    required int offset,
    required int limit,
  }) {
    return _repository.searchStudents(
      query: _query,
      offset: offset,
      limit: limit,
    );
  }

  void search(String query) {
    _query = query;
    loadInitial();
  }
}
