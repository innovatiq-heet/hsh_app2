import 'package:get/get.dart';

/// Offset/limit pagination state for list screens (student directory,
/// attendance/leave history). Default page size follows the new API's
/// larger max (spec §7.4) instead of the old hardcoded limit=100.
mixin PaginatedListMixin<T> on GetxController {
  static const int defaultPageSize = 200;

  final RxList<T> items = <T>[].obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isInitialLoading = true.obs;
  final RxBool hasMore = true.obs;
  final RxBool hasError = false.obs;
  int offset = 0;

  int get pageSize => defaultPageSize;

  Future<List<T>> fetchPage({required int offset, required int limit});

  Future<void> loadInitial() async {
    isInitialLoading.value = true;
    hasError.value = false;
    offset = 0;
    hasMore.value = true;
    try {
      final page = await fetchPage(offset: 0, limit: pageSize);
      items.assignAll(page);
      offset = page.length;
      hasMore.value = page.length == pageSize;
    } catch (_) {
      hasError.value = true;
    } finally {
      isInitialLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final page = await fetchPage(offset: offset, limit: pageSize);
      items.addAll(page);
      offset += page.length;
      hasMore.value = page.length == pageSize;
    } catch (_) {
      // Leave existing items in place; the "load more" trigger simply
      // stays available so the user can scroll to retry.
    } finally {
      isLoadingMore.value = false;
    }
  }
}
