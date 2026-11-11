import 'dart:async';

import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/network/repository/broadcasts/broadcasts_repository.dart';
import 'broadcast_admin_gate.dart';

/// Admin → Broadcast: sent broadcasts, newest first, paged. While any
/// broadcast is still `sending`, the first page is re-fetched every
/// [pollInterval] so its counts update.
class BroadcastHistoryController extends GetxController
    with LoadStateMixin, BroadcastAdminGate {
  BroadcastHistoryController({
    BroadcastsRepository? repository,
    this.pollInterval = const Duration(seconds: 5),
  }) : _repo = repository ?? Get.find<BroadcastsRepository>();

  static const pageSize = 20;

  final BroadcastsRepository _repo;
  final Duration pollInterval;

  final broadcasts = <Broadcast>[].obs;
  final total = 0.obs;
  final isLoadingMore = false.obs;

  Timer? _pollTimer;

  bool get hasMore => broadcasts.length < total.value;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    if (await ensureAdmin()) {
      await load();
    } else {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        final page = await _repo.history(limit: pageSize, offset: 0);
        broadcasts.assignAll(page.items);
        total.value = page.total;
        _updatePolling();
      }, showLoading: showLoading);

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore) return;
    isLoadingMore.value = true;
    try {
      final page = await _repo.history(limit: pageSize, offset: broadcasts.length);
      final known = broadcasts.map((b) => b.id).toSet();
      broadcasts.addAll(page.items.where((b) => !known.contains(b.id)));
      total.value = page.total;
    } catch (_) {
      // Keep what is shown; the next scroll retries.
    } finally {
      isLoadingMore.value = false;
    }
  }

  void _updatePolling() {
    final anySending = broadcasts.any((b) => b.isSending);
    if (!anySending) {
      _pollTimer?.cancel();
      _pollTimer = null;
    } else {
      _pollTimer ??= Timer.periodic(pollInterval, (_) => _poll());
    }
  }

  /// Refreshes the first page in place (sending broadcasts are the newest).
  Future<void> _poll() async {
    try {
      final page = await _repo.history(limit: pageSize, offset: 0);
      final fresh = {for (final b in page.items) b.id: b};
      final known = broadcasts.map((b) => b.id).toSet();
      final updated = [
        ...page.items.where((b) => !known.contains(b.id)),
        for (final b in broadcasts) fresh[b.id] ?? b,
      ];
      broadcasts.assignAll(updated);
      total.value = page.total;
    } catch (_) {
      // Try again on the next tick.
    }
    _updatePolling();
  }

  /// Called after a send so the new broadcast shows at the top.
  void addSent(Broadcast broadcast) {
    broadcasts.removeWhere((b) => b.id == broadcast.id);
    broadcasts.insert(0, broadcast);
    total.value = total.value + 1;
    _updatePolling();
  }
}
