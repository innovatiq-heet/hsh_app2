import 'dart:convert';
import 'dart:developer' as developer;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/user_role.dart';
import '../models/auth/user_session.dart';
import '../models/student_profile/student_profile_model.dart';
import '../network/api_client.dart';
import '../services/aadhar_service.dart';
import '../services/screen_time_service.dart';

/// Clean, OOP-based Session and Student Data Store backed by [SharedPreferences].
///
/// Encapsulates authentication token, active [UserSession], and [StudentProfileModel]
/// as strongly-typed, single-source-of-truth objects to eliminate data redundancy.
///
/// Provides fast, synchronous in-memory access for hot paths (e.g. AuthInterceptor)
/// while guaranteeing atomic, consistent persistence in SharedPreferences.
class SessionStore extends GetxService {
  static const _kToken = 'auth_token';
  static const _kUserSession = 'user_session';
  static const _kStudentProfile = 'student_profile';
  static const _kLastAttendanceDate = 'last_attendance_date';

  SharedPreferences? _prefs;

  // ---------- In-memory cached models (Single Source of Truth) ----------
  UserSession? _cachedSession;
  StudentProfileModel? _cachedStudentProfile;
  String? _cachedToken;
  String? _cachedLastAttendanceDate;

  @override
  void onInit() {
    super.onInit();
    _initStorage();
  }

  Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _initStorage() async {
    try {
      final prefs = await _instance;
      _cachedToken = prefs.getString(_kToken);

      final sessionJson = prefs.getString(_kUserSession);
      if (sessionJson != null && sessionJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(sessionJson);
          if (decoded is Map<String, dynamic>) {
            _cachedSession = UserSession.fromJson(decoded);
          }
        } catch (_) {}
      }

      final profileJson = prefs.getString(_kStudentProfile);
      if (profileJson != null && profileJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(profileJson);
          if (decoded is Map<String, dynamic>) {
            _cachedStudentProfile = StudentProfileModel.fromJson(decoded);
          }
        } catch (_) {}
      }

      _cachedLastAttendanceDate = prefs.getString(_kLastAttendanceDate);
    } catch (e) {
      developer.log('Failed to initialize SharedPreferences: $e', name: 'SessionStore');
    }
  }

  // ---------- Synchronous accessors (Hot path) ----------

  /// Synchronous access to currently loaded token.
  String? get currentToken => _cachedSession?.token ?? _cachedToken;

  /// Synchronous access to current user session model.
  UserSession? get currentSession => _cachedSession;

  /// Synchronous access to current student profile model.
  StudentProfileModel? get currentStudentProfile =>
      _cachedStudentProfile ?? _cachedSession?.studentProfile;

  // ---------- Session lifecycle ----------

  /// Persists the authenticated session and student data using clean OOP models.
  Future<void> saveSession({
    required String token,
    required UserRole role,
    required String email,
    required String name,
    String? phone,
    String? studentCode,
    String? aadhar,
    String? room,
    StudentProfileModel? studentProfile,
  }) async {
    final effectiveProfile = studentProfile ?? _cachedStudentProfile;

    final session = UserSession(
      token: token,
      role: role,
      name: name,
      email: email,
      phone: phone ?? '',
      studentCode: studentCode ?? '',
      room: room ?? '',
      studentProfile: effectiveProfile,
    );

    _cachedToken = token;
    _cachedSession = session;
    if (studentProfile != null) {
      _cachedStudentProfile = studentProfile;
    }

    try {
      final prefs = await _instance;
      await Future.wait([
        prefs.setString(_kToken, token),
        prefs.setString(_kUserSession, jsonEncode(session.toJson())),
        if (effectiveProfile != null)
          prefs.setString(_kStudentProfile, jsonEncode(effectiveProfile.toJson())),
      ]);
    } catch (e) {
      developer.log('Error saving session to SharedPreferences: $e', name: 'SessionStore');
    }

    // Set authorization on ApiClient
    if (Get.isRegistered<ApiClient>()) {
      Get.find<ApiClient>().setAuthToken(token);
    }

    // Screen time monitoring
    if (role.isStudentOrLeader && token.isNotEmpty) {
      await ScreenTimeService.startMonitoring(token);
    } else {
      await ScreenTimeService.stopMonitoring();
    }
  }

  /// Updates and persists student profile data without data redundancy.
  Future<void> saveStudentProfile(StudentProfileModel profile) async {
    _cachedStudentProfile = profile;
    if (_cachedSession != null) {
      _cachedSession = _cachedSession!.copyWith(studentProfile: profile);
    }

    try {
      final prefs = await _instance;
      await prefs.setString(_kStudentProfile, jsonEncode(profile.toJson()));
      if (_cachedSession != null) {
        await prefs.setString(_kUserSession, jsonEncode(_cachedSession!.toJson()));
      }
    } catch (e) {
      developer.log('Error updating student profile in SharedPreferences: $e', name: 'SessionStore');
    }
  }

  /// Complete, proper logout cleanup:
  /// - Removes token and student data from SharedPreferences
  /// - Wipes in-memory session and profile caches
  /// - Clears ApiClient authorization headers
  /// - Stops background services (ScreenTimeService)
  /// - Invalidates service caches (AadharService)
  Future<void> logout() async {
    _cachedToken = null;
    _cachedSession = null;
    _cachedStudentProfile = null;
    _cachedLastAttendanceDate = null;

    // 1. Wipe SharedPreferences
    try {
      final prefs = await _instance;
      await Future.wait([
        prefs.remove(_kToken),
        prefs.remove(_kUserSession),
        prefs.remove(_kStudentProfile),
        prefs.remove(_kLastAttendanceDate),
      ]);
    } catch (e) {
      developer.log('Error clearing SharedPreferences on logout: $e', name: 'SessionStore');
    }

    // 2. Clear ApiClient authorization
    if (Get.isRegistered<ApiClient>()) {
      Get.find<ApiClient>().setAuthToken(null);
    }

    // 3. Stop screen-time monitoring
    await ScreenTimeService.stopMonitoring();

    // 4. Invalidate Aadhar cache
    if (Get.isRegistered<AadharService>()) {
      Get.find<AadharService>().invalidate();
    }
  }

  /// Backward-compatible alias for logout().
  Future<void> clear() => logout();

  Future<void> clearAadhar() async {
    if (_cachedStudentProfile != null) {
      _cachedStudentProfile = _cachedStudentProfile!.copyWith();
    }
  }

  // ---------- Typed Lazy Getters & Helpers ----------

  Future<String?> get token async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    final prefs = await _instance;
    _cachedToken = prefs.getString(_kToken);
    return _cachedToken;
  }

  /// Asynchronous getter to ensure the full [UserSession] is loaded.
  Future<UserSession?> get userSession async {
    if (_cachedSession != null) return _cachedSession;
    await _ensureSessionLoaded();
    return _cachedSession;
  }

  /// Asynchronous getter to ensure the [StudentProfileModel] is loaded.
  Future<StudentProfileModel?> get studentProfile async {
    if (_cachedStudentProfile != null) return _cachedStudentProfile;
    await _ensureProfileLoaded();
    return _cachedStudentProfile ?? _cachedSession?.studentProfile;
  }

  Future<UserRole> get role async {
    if (_cachedSession != null) return _cachedSession!.role;
    await _ensureSessionLoaded();
    return _cachedSession?.role ?? UserRole.unknown;
  }

  Future<String?> get email async {
    if (_cachedSession != null) return _cachedSession!.email;
    await _ensureSessionLoaded();
    return _cachedSession?.email;
  }

  Future<String?> get name async {
    if (_cachedSession != null) return _cachedSession!.name;
    await _ensureSessionLoaded();
    return _cachedSession?.name;
  }

  Future<String?> get cachedAadhar async {
    if (_cachedStudentProfile != null && _cachedStudentProfile!.aadhar.isNotEmpty) {
      return _cachedStudentProfile!.aadhar;
    }
    await _ensureProfileLoaded();
    return _cachedStudentProfile?.aadhar;
  }

  Future<void> cacheAadhar(String aadhar) async {
    if (_cachedStudentProfile != null) {
      await saveStudentProfile(
        StudentProfileModel(
          aadhar: aadhar,
          firstName: _cachedStudentProfile!.firstName,
          middleName: _cachedStudentProfile!.middleName,
          lastName: _cachedStudentProfile!.lastName,
          phone: _cachedStudentProfile!.phone,
          whatsappNumber: _cachedStudentProfile!.whatsappNumber,
          email: _cachedStudentProfile!.email,
          room: _cachedStudentProfile!.room,
          status: _cachedStudentProfile!.status,
          subStatus: _cachedStudentProfile!.subStatus,
          bloodGroup: _cachedStudentProfile!.bloodGroup,
          dob: _cachedStudentProfile!.dob,
          address: _cachedStudentProfile!.address,
          pinCode: _cachedStudentProfile!.pinCode,
          fatherFirstName: _cachedStudentProfile!.fatherFirstName,
          fatherPhone: _cachedStudentProfile!.fatherPhone,
          fatherProfession: _cachedStudentProfile!.fatherProfession,
          motherFirstName: _cachedStudentProfile!.motherFirstName,
          motherPhone: _cachedStudentProfile!.motherPhone,
          playsCricket: _cachedStudentProfile!.playsCricket,
          playsBadminton: _cachedStudentProfile!.playsBadminton,
          goesToGym: _cachedStudentProfile!.goesToGym,
          vehicleNumber: _cachedStudentProfile!.vehicleNumber,
          category: _cachedStudentProfile!.category,
          groupName: _cachedStudentProfile!.groupName,
          bankCode: _cachedStudentProfile!.bankCode,
          bankCodeChecked: _cachedStudentProfile!.bankCodeChecked,
          notes: _cachedStudentProfile!.notes,
        ),
      );
    }
  }

  Future<String?> get cachedPhone async {
    if (_cachedStudentProfile != null && _cachedStudentProfile!.phone.isNotEmpty) {
      return _cachedStudentProfile!.phone;
    }
    if (_cachedSession != null && _cachedSession!.phone.isNotEmpty) {
      return _cachedSession!.phone;
    }
    await _ensureProfileLoaded();
    return _cachedStudentProfile?.phone ?? _cachedSession?.phone;
  }

  Future<void> cachePhone(String phone) async {
    if (_cachedStudentProfile != null) {
      await saveStudentProfile(_cachedStudentProfile!.copyWith(phone: phone));
    }
  }

  Future<String?> get cachedStudentCode async {
    if (_cachedStudentProfile != null && _cachedStudentProfile!.bankCode.isNotEmpty) {
      return _cachedStudentProfile!.bankCode;
    }
    if (_cachedSession != null && _cachedSession!.studentCode.isNotEmpty) {
      return _cachedSession!.studentCode;
    }
    await _ensureProfileLoaded();
    return _cachedStudentProfile?.bankCode ?? _cachedSession?.studentCode;
  }

  Future<void> cacheStudentCode(String code) async {
    if (_cachedSession != null) {
      _cachedSession = _cachedSession!.copyWith(studentCode: code);
      final prefs = await _instance;
      await prefs.setString(_kUserSession, jsonEncode(_cachedSession!.toJson()));
    }
  }

  Future<String?> get cachedBloodGroup async {
    if (_cachedStudentProfile != null && _cachedStudentProfile!.bloodGroup.isNotEmpty) {
      return _cachedStudentProfile!.bloodGroup;
    }
    await _ensureProfileLoaded();
    return _cachedStudentProfile?.bloodGroup;
  }

  Future<void> cacheBloodGroup(String bg) async {
    if (_cachedStudentProfile != null) {
      await saveStudentProfile(_cachedStudentProfile!.copyWith(bloodGroup: bg));
    }
  }

  Future<String?> get cachedVehicleNumber async {
    if (_cachedStudentProfile != null && _cachedStudentProfile!.vehicleNumber.isNotEmpty) {
      return _cachedStudentProfile!.vehicleNumber;
    }
    await _ensureProfileLoaded();
    return _cachedStudentProfile?.vehicleNumber;
  }

  Future<void> cacheVehicleNumber(String vehicle) async {
    if (_cachedStudentProfile != null) {
      await saveStudentProfile(_cachedStudentProfile!.copyWith(vehicleNumber: vehicle));
    }
  }

  Future<String?> get cachedRoom async {
    if (_cachedStudentProfile != null && _cachedStudentProfile!.room.isNotEmpty) {
      return _cachedStudentProfile!.room;
    }
    if (_cachedSession != null && _cachedSession!.room.isNotEmpty) {
      return _cachedSession!.room;
    }
    await _ensureProfileLoaded();
    return _cachedStudentProfile?.room ?? _cachedSession?.room;
  }

  Future<void> cacheRoom(String room) async {
    if (_cachedStudentProfile != null) {
      await saveStudentProfile(
        StudentProfileModel(
          aadhar: _cachedStudentProfile!.aadhar,
          firstName: _cachedStudentProfile!.firstName,
          middleName: _cachedStudentProfile!.middleName,
          lastName: _cachedStudentProfile!.lastName,
          phone: _cachedStudentProfile!.phone,
          whatsappNumber: _cachedStudentProfile!.whatsappNumber,
          email: _cachedStudentProfile!.email,
          room: room,
          status: _cachedStudentProfile!.status,
          subStatus: _cachedStudentProfile!.subStatus,
          bloodGroup: _cachedStudentProfile!.bloodGroup,
          dob: _cachedStudentProfile!.dob,
          address: _cachedStudentProfile!.address,
          pinCode: _cachedStudentProfile!.pinCode,
          fatherFirstName: _cachedStudentProfile!.fatherFirstName,
          fatherPhone: _cachedStudentProfile!.fatherPhone,
          fatherProfession: _cachedStudentProfile!.fatherProfession,
          motherFirstName: _cachedStudentProfile!.motherFirstName,
          motherPhone: _cachedStudentProfile!.motherPhone,
          playsCricket: _cachedStudentProfile!.playsCricket,
          playsBadminton: _cachedStudentProfile!.playsBadminton,
          goesToGym: _cachedStudentProfile!.goesToGym,
          vehicleNumber: _cachedStudentProfile!.vehicleNumber,
          category: _cachedStudentProfile!.category,
          groupName: _cachedStudentProfile!.groupName,
          bankCode: _cachedStudentProfile!.bankCode,
          bankCodeChecked: _cachedStudentProfile!.bankCodeChecked,
          notes: _cachedStudentProfile!.notes,
        ),
      );
    }
  }

  Future<String?> get lastAttendanceDate async {
    if (_cachedLastAttendanceDate != null) return _cachedLastAttendanceDate;
    final prefs = await _instance;
    _cachedLastAttendanceDate = prefs.getString(_kLastAttendanceDate);
    return _cachedLastAttendanceDate;
  }

  Future<void> saveLastAttendanceDate(String date) async {
    _cachedLastAttendanceDate = date;
    final prefs = await _instance;
    await prefs.setString(_kLastAttendanceDate, date);
  }

  Future<bool> get hasSession async => (await token) != null && (await token)!.isNotEmpty;

  Future<void> _ensureSessionLoaded() async {
    if (_cachedSession != null) return;
    final prefs = await _instance;
    final jsonStr = prefs.getString(_kUserSession);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr);
        if (map is Map<String, dynamic>) {
          _cachedSession = UserSession.fromJson(map);
        }
      } catch (_) {}
    }
  }

  Future<void> _ensureProfileLoaded() async {
    if (_cachedStudentProfile != null) return;
    final prefs = await _instance;
    final jsonStr = prefs.getString(_kStudentProfile);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr);
        if (map is Map<String, dynamic>) {
          _cachedStudentProfile = StudentProfileModel.fromJson(map);
        }
      } catch (_) {}
    }
  }
}
