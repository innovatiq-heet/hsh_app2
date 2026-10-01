import 'package:get/get.dart';
import '../../network/api_exception.dart';

/// Standard loading / error / content lifecycle for any controller that
/// fetches data on init.
///
/// Wrap async work in [guard] instead of hand-rolling `isLoading`/`hasError`/
/// `finally` in every controller. Pair with `AsyncStateView` on the screen
/// side to render the three states consistently.
///
/// ```dart
/// class MyController extends GetxController with LoadStateMixin {
///   @override
///   void onInit() {
///     super.onInit();
///     load();
///   }
///
///   Future<void> load() => guard(() async {
///     items.assignAll(await _repo.list());
///   });
/// }
/// ```
mixin LoadStateMixin on GetxController {
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  /// Wraps [action] with loading/error state management.
  ///
  /// Set [showLoading] to `false` for silent background refreshes where you
  /// don't want to flash the loading indicator (e.g. pull-to-refresh after
  /// content is already shown).
  Future<void> guard(
    Future<void> Function() action, {
    bool showLoading = true,
  }) async {
    if (showLoading) isLoading.value = true;
    hasError.value = false;
    try {
      await action();
    } on ApiException catch (e) {
      hasError.value = true;
      errorMessage.value = e.message;
    } catch (_) {
      hasError.value = true;
      errorMessage.value = 'Something went wrong. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }
}
