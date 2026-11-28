import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../network/api_client.dart';
import 'screen_time_service.dart';

/// Parsed server version metadata when an app update is required.
class ForceUpdateInfo {
  const ForceUpdateInfo({
    required this.latestVersionCode,
    required this.minVersionCode,
    required this.latestVersionName,
    required this.downloadUrl,
    required this.message,
  });

  final int latestVersionCode;
  final int minVersionCode;
  final String latestVersionName;
  final String downloadUrl;
  final String message;
}

/// Checks `GET /version` against the installed build number and blocks app usage
/// with a non-dismissible prompt whenever `force_update` is enabled and the
/// installed build is older than `min_version_code`.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String _defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.avd_hsh.app';

  bool _isDialogShowing = false;
  bool _checking = false;

  /// Pure evaluator for `GET /version` payloads; returns non-null only when a
  /// mandatory update is required for [currentBuildNumber].
  static ForceUpdateInfo? evaluateVersionResponse(
    Map<String, dynamic> payload,
    int currentBuildNumber, {
    String? mediaBaseUrl,
  }) {
    if (currentBuildNumber <= 0) return null;

    final rawData = payload['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : payload;

    final forceUpdate = _toBool(data['force_update']);
    if (!forceUpdate) return null;

    final latestCode = _toInt(data['latest_version_code']);
    final minCodeRaw = _toInt(data['min_version_code']);
    final requiredCode = minCodeRaw > 0 ? minCodeRaw : latestCode;
    if (requiredCode <= 0 || currentBuildNumber >= requiredCode) {
      return null;
    }

    final latestName = (data['latest_version_name'] ?? '').toString().trim();
    final message = (data['update_message'] ?? '').toString().trim();
    final downloadUrl = _resolveDownloadUrl(
      (data['apk_url'] ?? '').toString().trim(),
      mediaBaseUrl: mediaBaseUrl ?? AppConfig.mediaBaseUrl,
    );

    return ForceUpdateInfo(
      latestVersionCode: latestCode > 0 ? latestCode : requiredCode,
      minVersionCode: requiredCode,
      latestVersionName: latestName.isNotEmpty ? latestName : '$requiredCode',
      downloadUrl: downloadUrl,
      message: message.isNotEmpty
          ? message
          : 'A required update is available. Please update HSH Connect to continue.',
    );
  }

  /// Queries `GET /version` and displays a blocking update dialog if required.
  ///
  /// Returns `true` when the app must stay blocked on the update prompt. Fails
  /// open (`false`) on network errors or missing dependencies so offline use is
  /// never bricked.
  Future<bool> enforceForceUpdateIfNeeded({VoidCallback? onCleared}) async {
    if (_isDialogShowing) return true;
    if (_checking) return false;
    if (!Get.isRegistered<ApiClient>()) return false;

    _checking = true;
    try {
      final info = await fetchRequiredUpdate();
      if (info == null) return false;

      if (Get.context != null) {
        _showBlockingDialog(info, onCleared: onCleared);
      }
      return true;
    } catch (e) {
      developer.log('Force update check failed: $e', name: 'AppUpdate');
      return false;
    } finally {
      _checking = false;
    }
  }

  Future<ForceUpdateInfo?> fetchRequiredUpdate() async {
    if (!Get.isRegistered<ApiClient>()) return null;
    final dio = Get.find<ApiClient>().dio;
    final resp = await dio.get<dynamic>(
      '/version',
      options: Options(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
      ),
    );
    final body = resp.data;
    if (body is! Map) return null;

    final pkg = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(pkg.buildNumber.trim()) ?? 0;
    return evaluateVersionResponse(
      Map<String, dynamic>.from(body),
      currentBuild,
    );
  }

  void _showBlockingDialog(ForceUpdateInfo info, {VoidCallback? onCleared}) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    Get.dialog<void>(
      PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Color(0xFF1A4B8C)),
              SizedBox(width: 10),
              Expanded(child: Text('Update Required')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.message),
              const SizedBox(height: 12),
              Text(
                'Required version: v${info.latestVersionName} (Build ${info.minVersionCode})',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF5A6577),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final stillNeeded = await fetchRequiredUpdate();
                if (stillNeeded == null && (Get.isDialogOpen ?? false)) {
                  _isDialogShowing = false;
                  Get.back<void>();
                  onCleared?.call();
                }
              },
              child: const Text('Check Again'),
            ),
            FilledButton.icon(
              onPressed: () => _launchUpdate(info.downloadUrl),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Update Now'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    ).whenComplete(() {
      _isDialogShowing = false;
    });
  }

  Future<void> _launchUpdate(String url) async {
    // Allow Play Store / Package Installer briefly even when app installs are blocked.
    await ScreenTimeService.grantUpdatePass();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _resolveDownloadUrl(
    String rawUrl, {
    required String mediaBaseUrl,
  }) {
    if (rawUrl.isEmpty) return _defaultPlayStoreUrl;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    if (rawUrl.startsWith('/')) {
      final base = mediaBaseUrl.endsWith('/')
          ? mediaBaseUrl.substring(0, mediaBaseUrl.length - 1)
          : mediaBaseUrl;
      return '$base$rawUrl';
    }
    return rawUrl;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }
}
