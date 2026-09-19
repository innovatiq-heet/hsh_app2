import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../common_enums/user_role.dart';

/// Cached session/identity, replacing SharedPreferences['auth_token'] /
/// SharedPreferences['student_aadhar'] from the old app. Backed by
/// flutter_secure_storage so the token is never in plaintext prefs.
///
/// `aadhar` is resolved lazily from the fee-summary/laundry-balance calls
/// (see AadharResolvingMixin) and cached here — it is never returned by
/// login itself.
///
/// The first Keystore-backed read/write on some Android devices (notably
/// Xiaomi/MIUI) can stall for a long time or hang outright. Every call is
/// timeout-guarded so a slow Keystore never blocks app startup — a timeout
/// is treated the same as "no value stored".
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kRole = 'user_role';
  static const _kAadhar = 'student_aadhar';
  static const _kEmail = 'user_email';
  static const _kName = 'user_name';

  static const _timeout = Duration(seconds: 5);

  String? _cachedToken;
  UserRole? _cachedRole;
  String? _cachedEmail;
  String? _cachedName;
  String? _cachedAadhar;

  /// Synchronous access to the currently loaded token in memory.
  String? get currentToken => _cachedToken;

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key).timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: read($key) failed or timed out: $e',
        name: 'SessionStore',
      );
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value).timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: write($key) failed or timed out: $e',
        name: 'SessionStore',
      );
    }
  }

  Future<void> saveSession({
    required String token,
    required UserRole role,
    required String email,
    required String name,
  }) async {
    _cachedToken = token;
    _cachedRole = role;
    _cachedEmail = email;
    _cachedName = name;

    await clearAadhar();
    await Future.wait([
      _write(_kToken, token),
      _write(_kRole, role.apiValue),
      _write(_kEmail, email),
      _write(_kName, name),
    ]);
  }

  Future<void> clearAadhar() async {
    try {
      await _storage.delete(key: _kAadhar).timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: clearAadhar failed: $e',
        name: 'SessionStore',
      );
    }
  }

  Future<String?> get token => _read(_kToken);
  // Future<String?> get token async {
  //   if (_cachedToken != null && _cachedToken!.isNotEmpty) {
  //     return _cachedToken;
  //   }
  //   _cachedToken = await _read(_kToken);
  //   return _cachedToken;
  // }

  Future<UserRole> get role async {
    if (_cachedRole != null) return _cachedRole!;
    final value = await _read(_kRole);
    _cachedRole = UserRoleX.fromApi(value);
    return _cachedRole!;
  }

  Future<String?> get email async {
    if (_cachedEmail != null) return _cachedEmail;
    _cachedEmail = await _read(_kEmail);
    return _cachedEmail;
  }

  Future<String?> get name async {
    if (_cachedName != null) return _cachedName;
    _cachedName = await _read(_kName);
    return _cachedName;
  }

  Future<void> cacheAadhar(String aadhar) {
    _cachedAadhar = aadhar;
    return _write(_kAadhar, aadhar);
  }

  Future<String?> get cachedAadhar async {
    if (_cachedAadhar != null) return _cachedAadhar;
    _cachedAadhar = await _read(_kAadhar);
    return _cachedAadhar;
  }

  Future<bool> get hasSession async => (await token) != null;

  Future<void> clear() async {
    _cachedToken = null;
    _cachedRole = null;
    _cachedEmail = null;
    _cachedName = null;
    _cachedAadhar = null;

    try {
      await _storage.deleteAll().timeout(_timeout);
    } catch (e) {
      developer.log(
        'SessionStore: clear() failed or timed out: $e',
        name: 'SessionStore',
      );
    }
  }
}

