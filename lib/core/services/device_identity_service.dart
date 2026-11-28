import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Immutable snapshot describing this app installation + phone hardware.
class DeviceIdentityPayload {
  const DeviceIdentityPayload({
    required this.deviceUuid,
    this.deviceModel,
    this.hardwareId,
    this.osVersion,
    this.appVersion,
  });

  final String deviceUuid;
  final String? deviceModel;
  final String? hardwareId;
  final String? osVersion;
  final String? appVersion;

  Map<String, dynamic> toJson() => {
        'device_uuid': deviceUuid,
        if (deviceModel != null && deviceModel!.isNotEmpty)
          'device_model': deviceModel,
        if (hardwareId != null && hardwareId!.isNotEmpty)
          'hardware_id': hardwareId,
        if (osVersion != null && osVersion!.isNotEmpty) 'os_version': osVersion,
        if (appVersion != null && appVersion!.isNotEmpty)
          'app_version': appVersion,
      };
}

/// Generates and stores a cryptographically random per-install `device_uuid` in
/// secure key-backed storage (`FlutterSecureStorage`) plus hardware metadata.
///
/// Uninstalling/reinstalling the app or signing in from another device yields
/// a new `device_uuid`, allowing the backend to gate the login for admin
/// approval while still distinguishing a reinstall on the same hardware from a
/// completely different phone.
class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance = DeviceIdentityService._();

  static const String _storageKey = 'hsh_install_device_uuid';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedUuid;
  Future<DeviceIdentityPayload>? _inFlight;

  @visibleForTesting
  static Future<DeviceIdentityPayload> Function()? testOverride;

  /// Returns a generated UUID v4 string (`8-4-4-4-12` lowercase hex).
  static String generateUuidV4([Random? rng]) {
    final random = rng ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  Future<DeviceIdentityPayload> getIdentity() {
    if (testOverride != null) return testOverride!();
    return _inFlight ??= _loadIdentity().whenComplete(() => _inFlight = null);
  }

  Future<DeviceIdentityPayload> _loadIdentity() async {
    final uuid = await _getOrCreateInstallUuid();
    String? model;
    String? hardwareId;
    String? osVersion;
    String? appVersion;

    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final mfg = a.manufacturer.trim();
        final mdl = a.model.trim();
        model = mfg.isNotEmpty && !mdl.toLowerCase().startsWith(mfg.toLowerCase())
            ? '$mfg $mdl'
            : mdl;
        hardwareId = a.id.trim().isNotEmpty ? a.id.trim() : a.fingerprint.trim();
        osVersion = 'Android ${a.version.release}'.trim();
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        model = ios.utsname.machine.trim();
        hardwareId = ios.identifierForVendor?.trim();
        osVersion = 'iOS ${ios.systemVersion}'.trim();
      }
    } catch (e) {
      developer.log('Device info lookup skipped: $e', name: 'DeviceIdentity');
    }

    try {
      final pkg = await PackageInfo.fromPlatform();
      if (pkg.version.isNotEmpty) {
        appVersion = '${pkg.version}+${pkg.buildNumber}';
      }
    } catch (_) {}

    return DeviceIdentityPayload(
      deviceUuid: uuid,
      deviceModel: model,
      hardwareId: hardwareId,
      osVersion: osVersion,
      appVersion: appVersion,
    );
  }

  Future<String> _getOrCreateInstallUuid() async {
    if (_cachedUuid != null && _cachedUuid!.isNotEmpty) return _cachedUuid!;

    try {
      final existing = await _storage.read(key: _storageKey);
      if (existing != null && existing.trim().isNotEmpty) {
        _cachedUuid = existing.trim();
        return _cachedUuid!;
      }
    } catch (e) {
      developer.log('Secure storage read error: $e', name: 'DeviceIdentity');
    }

    final fresh = generateUuidV4();
    _cachedUuid = fresh;
    try {
      await _storage.write(key: _storageKey, value: fresh);
    } catch (e) {
      developer.log('Secure storage write error: $e', name: 'DeviceIdentity');
    }
    return fresh;
  }
}
