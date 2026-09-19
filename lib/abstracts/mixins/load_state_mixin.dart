import 'package:get/get.dart';
import '../../network/api_exception.dart';

/// Standard loading/error/content lifecycle for any controller that fetches
/// data on init. Wrap the fetch in [guard] instead of hand-rolling
/// try/isLoading/finally in every controller — pair with [AsyncStateView] on
/// the screen side to render the three states consistently.
mixin LoadStateMixin on GetxController {
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

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
