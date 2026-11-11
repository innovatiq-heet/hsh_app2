import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/network/repository/broadcasts/broadcasts_repository.dart';

/// Student → More → Announcements: broadcasts addressed to this student.
///
/// Opened from a push with `{broadcast_id}` as the route argument, it opens
/// that message once the list has loaded ([pendingOpenId]).
class BroadcastInboxController extends GetxController with LoadStateMixin {
  BroadcastInboxController({BroadcastsRepository? repository, int? openBroadcastId})
      : _repo = repository ?? Get.find<BroadcastsRepository>(),
        pendingOpenId = openBroadcastId;

  static const pageSize = 20;

  final BroadcastsRepository _repo;

  final items = <InboxBroadcast>[].obs;
  final total = 0.obs;
  final unreadCount = 0.obs;
  final isLoadingMore = false.obs;

  /// Message to open after the first load (from a push tap).
  int? pendingOpenId;

  /// Set to the message the screen should show, once found.
  final openRequest = Rxn<InboxBroadcast>();

  bool get hasMore => items.length < total.value;

  @override
  void onInit() {
    super.onInit();
    if (pendingOpenId == null) {
      final args = Get.arguments;
      if (args is Map) {
        pendingOpenId = int.tryParse(args['broadcast_id']?.toString() ?? '');
      }
    }
    load();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        final page = await _repo.inbox(limit: pageSize, offset: 0);
        items.assignAll(page.items);
        total.value = page.total;
        unreadCount.value = page.unreadCount;
        _openPending();
      }, showLoading: showLoading);

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore) return;
    isLoadingMore.value = true;
    try {
      final page = await _repo.inbox(limit: pageSize, offset: items.length);
      final known = items.map((i) => i.id).toSet();
      items.addAll(page.items.where((i) => !known.contains(i.id)));
      total.value = page.total;
      unreadCount.value = page.unreadCount;
    } catch (_) {
      // Keep what is shown.
    } finally {
      isLoadingMore.value = false;
    }
  }

  void _openPending() {
    final id = pendingOpenId;
    if (id == null) return;
    pendingOpenId = null;
    final match = items.firstWhereOrNull((i) => i.id == id);
    if (match != null) openRequest.value = match;
  }

  /// Marks [item] read: optimistic, rolled back if the request fails.
  Future<void> markRead(InboxBroadcast item) async {
    if (item.isRead) return;
    final index = items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;
    final before = items[index];
    items[index] = before.copyWith(readAt: DateTime.now().toUtc());
    if (unreadCount.value > 0) unreadCount.value--;
    try {
      final readAt = await _repo.markRead(item.id);
      final i = items.indexWhere((x) => x.id == item.id);
      if (i != -1 && readAt != null) items[i] = items[i].copyWith(readAt: readAt);
    } catch (_) {
      final i = items.indexWhere((x) => x.id == item.id);
      if (i != -1) items[i] = before;
      unreadCount.value++;
    }
  }
}
