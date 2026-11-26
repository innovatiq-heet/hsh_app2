import 'dart:async';

import 'package:flutter/material.dart';
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

  final search = ''.obs;
  final searchController = TextEditingController();
  final channelFilter = Rxn<BroadcastChannel>();
  final statusFilter = Rxn<BroadcastStatus>();

  Timer? _pollTimer;

  bool get hasMore => broadcasts.length < total.value;

  void onSearchChanged(String value) => search.value = value;

  void clearSearch() {
    searchController.clear();
    search.value = '';
  }

  int get activeFilterCount {
    var count = 0;
    if (channelFilter.value != null) count++;
    if (statusFilter.value != null) count++;
    return count;
  }

  void resetFilters() {
    channelFilter.value = null;
    statusFilter.value = null;
  }

  List<Broadcast> get visibleBroadcasts {
    final q = search.value.trim().toLowerCase();
    final ch = channelFilter.value;
    final st = statusFilter.value;
    return broadcasts.where((b) {
      if (ch != null && b.channels != ch) return false;
      if (st != null && b.status != st) return false;
      if (q.isEmpty) return true;
      return b.displayTitle.toLowerCase().contains(q) ||
          b.message.toLowerCase().contains(q) ||
          b.senderName.toLowerCase().contains(q) ||
          b.tags.any((t) => t.name.toLowerCase().contains(q));
    }).toList();
  }

  int countByChannel(BroadcastChannel? ch) =>
      ch == null ? broadcasts.length : broadcasts.where((b) => b.channels == ch).length;

  int get totalReached => broadcasts.fold<int>(0, (sum, b) => sum + b.recipientCount);
  int get totalRead => broadcasts.fold<int>(0, (sum, b) => sum + b.readCount);

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    if (await ensureAdminOrLeader()) {
      await load();
    } else {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    searchController.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        final page = await _repo.history(limit: pageSize, offset: 0, isLeader: isLeaderView.value);
        broadcasts.assignAll(page.items);
        total.value = page.total;
        _updatePolling();
      }, showLoading: showLoading);

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore) return;
    isLoadingMore.value = true;
    try {
      final page = await _repo.history(limit: pageSize, offset: broadcasts.length, isLeader: isLeaderView.value);
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
      final page = await _repo.history(limit: pageSize, offset: 0, isLeader: isLeaderView.value);
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
