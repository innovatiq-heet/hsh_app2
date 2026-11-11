import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/network/repository/broadcasts/broadcasts_repository.dart';
import 'broadcast_admin_gate.dart';

enum RecipientFilter { all, read, unread, noDevice }

/// Admin → Broadcast → one broadcast: message, counts, recipients.
/// Opened with the broadcast id (or a [Broadcast]) as the route argument.
class BroadcastDetailController extends GetxController
    with LoadStateMixin, BroadcastAdminGate {
  BroadcastDetailController({BroadcastsRepository? repository, int? broadcastId})
      : _repo = repository ?? Get.find<BroadcastsRepository>(),
        _id = broadcastId;

  final BroadcastsRepository _repo;
  int? _id;

  final broadcast = Rxn<Broadcast>();
  final filter = RecipientFilter.all.obs;

  List<BroadcastRecipient> get visibleRecipients {
    final all = broadcast.value?.recipients ?? const [];
    switch (filter.value) {
      case RecipientFilter.all:
        return all;
      case RecipientFilter.read:
        return all.where((r) => r.isRead).toList();
      case RecipientFilter.unread:
        return all.where((r) => !r.isRead).toList();
      case RecipientFilter.noDevice:
        return all.where((r) => r.pushStatus == PushStatus.noDevice).toList();
    }
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (_id == null) {
      if (args is Broadcast) {
        _id = args.id;
        broadcast.value = args; // show the summary while recipients load
      } else {
        _id = int.tryParse(args?.toString() ?? '');
      }
    }
    _start();
  }

  Future<void> _start() async {
    if (await ensureAdmin()) {
      await load();
    } else {
      isLoading.value = false;
    }
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        final id = _id;
        if (id == null) throw StateError('No broadcast id');
        broadcast.value = await _repo.detail(id);
      }, showLoading: showLoading && broadcast.value == null);
}
