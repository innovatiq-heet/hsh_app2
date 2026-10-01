import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Global controller to monitor real-time internet connectivity.
/// Combines hardware interface changes from [Connectivity] with active DNS checks
/// to prevent false positives when connected to Wi-Fi without internet access.
class NetworkController extends GetxController {
  static NetworkController get to => Get.find<NetworkController>();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Reactive state whether device currently has verified internet access.
  final RxBool isConnected = true.obs;

  /// Reactive state for when user manually taps "Try Again".
  final RxBool isChecking = false.obs;

  /// Trigger to display the animated "Back Online" success toast.
  final RxBool showRestoredBanner = false.obs;

  bool _hasEverDisconnected = false;
  Timer? _bannerDismissTimer;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      final initialResults = await _connectivity.checkConnectivity();
      await _evaluateConnection(initialResults);
    } catch (_) {
      // If check fails initially, perform DNS probe
      await _checkRealInternet();
    }

    // Listen to network interface changes
    _subscription = _connectivity.onConnectivityChanged.listen(_evaluateConnection);
  }

  Future<void> _evaluateConnection(List<ConnectivityResult> results) async {
    // If no network interface is active, immediately mark disconnected
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      _setOffline();
      return;
    }

    // Interface is active (Wi-Fi, Mobile, Ethernet, etc.) -> verify actual internet reachability
    await _checkRealInternet();
  }

  /// Verifies active internet reachability using DNS lookups.
  Future<bool> _checkRealInternet() async {
    try {
      final lookup = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 4));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        _setOnline();
        return true;
      }
    } catch (_) {
      try {
        // Fallback secondary probe
        final fallback = await InternetAddress.lookup('one.one.one.one')
            .timeout(const Duration(seconds: 3));
        if (fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty) {
          _setOnline();
          return true;
        }
      } catch (_) {
        // Both probes failed
      }
    }

    _setOffline();
    return false;
  }

  void _setOffline() {
    if (isConnected.value) {
      isConnected.value = false;
      _hasEverDisconnected = true;
      showRestoredBanner.value = false;
      _bannerDismissTimer?.cancel();
    }
  }

  void _setOnline() {
    if (!isConnected.value) {
      isConnected.value = true;
      if (_hasEverDisconnected) {
        _triggerRestoredBanner();
      }
    }
  }

  void _triggerRestoredBanner() {
    showRestoredBanner.value = true;
    _bannerDismissTimer?.cancel();
    _bannerDismissTimer = Timer(const Duration(seconds: 3), () {
      showRestoredBanner.value = false;
    });
  }

  /// Manually re-check connection (triggered by "Try Again" button).
  Future<bool> checkConnection() async {
    if (isChecking.value) return isConnected.value;

    isChecking.value = true;
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
        _setOffline();
        await Future.delayed(const Duration(milliseconds: 400));
        return false;
      }

      final reachable = await _checkRealInternet();
      // Add slight delay for natural UX so user sees spinner feedback
      await Future.delayed(const Duration(milliseconds: 500));
      return reachable;
    } finally {
      isChecking.value = false;
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _bannerDismissTimer?.cancel();
    super.onClose();
  }
}
