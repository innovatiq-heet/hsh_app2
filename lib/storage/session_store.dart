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
    await Future.wait([
      _write(_kToken, token),
      _write(_kRole, role.apiValue),
      _write(_kEmail, email),
      _write(_kName, name),
    ]);
  }

  Future<String?> get token => _read(_kToken);

  Future<UserRole> get role async {
    final value = await _read(_kRole);
    return UserRoleX.fromApi(value);
  }

  Future<String?> get email => _read(_kEmail);

  Future<String?> get name => _read(_kName);

  Future<void> cacheAadhar(String aadhar) => _write(_kAadhar, aadhar);

  Future<String?> get cachedAadhar => _read(_kAadhar);

  Future<bool> get hasSession async => (await token) != null;

  Future<void> clear() async {
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
