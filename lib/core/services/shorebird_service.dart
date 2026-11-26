import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  ShorebirdService._();
  static final ShorebirdService instance = ShorebirdService._();

  final ShorebirdUpdater _updater = ShorebirdUpdater();
  PackageInfo? _packageInfo;

  bool get isAvailable => _updater.isAvailable;

  /// The real installed app version and build number (from the platform,
  /// not a hand-maintained constant), cached after the first read.
  Future<PackageInfo> _info() async => _packageInfo ??= await PackageInfo.fromPlatform();

  /// e.g. "v1.2.1 (Build 36)", read live from the installed app.
  Future<String> versionDisplay() async {
    final info = await _info();
    return 'v${info.version} (Build ${info.buildNumber})';
  }

  /// Check current patch number (null if running the base release without patches)
  Future<int?> getCurrentPatchNumber() async {
    if (!isAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('[Shorebird] Error reading patch: $e');
      return null;
    }
  }

  /// Returns clean patch label e.g. "Patch #2", "Base Release", or "Dev Build"
  Future<String> getPatchLabel() async {
    if (!isAvailable) {
      return 'Dev Build';
    }
    final patch = await getCurrentPatchNumber();
    if (patch == null) {
      return 'Base Release';
    }
    return 'Patch #$patch';
  }

  /// Returns combined version string: e.g. "v1.2.1 (Build 36) • Patch #3" or "v1.2.1 (Build 36) • Base Release"
  Future<String> getFullVersionInfo() async {
    final results = await Future.wait([versionDisplay(), getPatchLabel()]);
    return '${results[0]} • ${results[1]}';
  }

  /// Check for any pending OTA patches and download in background
  Future<bool> checkForUpdatesAndDownload() async {
    if (!isAvailable) return false;
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('[Shorebird] New patch found, downloading in background...');
        await _updater.update();
        debugPrint('[Shorebird] Patch downloaded! Will apply on next restart.');
        return true;
      } else {
        debugPrint('[Shorebird] App is up to date.');
      }
    } catch (e) {
      debugPrint('[Shorebird] Error checking for updates: $e');
    }
    return false;
  }
}
