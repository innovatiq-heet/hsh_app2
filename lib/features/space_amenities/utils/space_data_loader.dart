import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';

/// Generic load/error/retry for a single async fetch, so Space & Amenities
/// detail screens don't each hand-roll `_loading`/`_error`/`setState`
/// boilerplate — the exact thing [LoadStateMixin] exists for, which only
/// [SpaceAmenitiesHomeController] was using before this.
///
/// Not registered with Get: each screen creates its own instance directly, so
/// there's no stale state across navigation and no manual disposal to
/// remember. Pair with `Obx` on the screen side, same as any other
/// [LoadStateMixin] controller.
///
/// ```dart
/// late final _loader = SpaceDataLoader<FloorDetailsResponse>(
///   () => _repo.floorDetails(widget.floorId),
/// );
/// ```
class SpaceDataLoader<T> extends GetxController with LoadStateMixin {
  SpaceDataLoader(this._fetch);
  final Future<T> Function() _fetch;

  final Rxn<T> data = Rxn<T>();

  Future<void> load({bool showLoading = true}) => guard(() async {
        data.value = await _fetch();
      }, showLoading: showLoading);
}
