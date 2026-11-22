/// App-wide runtime configuration.
///
/// All constants here are compile-time values so they can be `const` and
/// inlined by the compiler. Swap [baseUrl] for a real host before release.
class AppConfig {
  AppConfig._();

  static const String host = 'https://lightcoral-eel-306042.hostingersite.com';
  static const String baseUrl = '$host/api';
  static const String healthUrl = '$host/';

  /// App release and build version info
  static const String appVersion = '1.0.1+2';
  static const String appVersionDisplay = 'v1.0.1 (Build 2)';

  /// Live hosted attendance schedule endpoint.
  static const String attendanceScheduleUrl =
      'https://lightcoral-eel-306042.hostingersite.com/api/schedule-data';

  /// External student basic-details endpoint.
  static const String studentBasicDetailsUrl =
      'https://api.avdvvn.org/public/getStudentBasicDetails';
  static const String studentBasicDetailsAuthToken = 'aF92Kx7QmN4Lp8Vz';

  /// Server origin without the `/api` prefix — statically served uploads
  /// (e.g. complaint photos mounted at `/uploads`) live here, not under `/api`.
  static String get mediaBaseUrl => baseUrl.endsWith('/api')
      ? baseUrl.substring(0, baseUrl.length - 4)
      : baseUrl;

  /// Public student photos: `<base>/<12-digit Aadhar>.jpg`. A student with
  /// no photo answers 403, so callers must fall back to initials.
  static const String studentPhotoBaseUrl = '$photoStorageUrl/student/personal';

  /// Public photo storage. Student, father and mother photos all live in it,
  /// each named after the **student's** 12-digit Aadhar:
  /// `student/personal/`, `father/personal/`, `mother/personal/<aadhar>.jpg`.
  static const String photoStorageUrl =
      'https://storage.googleapis.com/hari-saurabh-hostel-78d58.appspot.com';

  /// Artificial delay used in repositories that serve mock/local data.
  static const Duration mockNetworkDelay = Duration(milliseconds: 600);

  /// Authorized mobile numbers permitted to log in as Admin.
  static const List<String> allowedAdminPhoneNumbers = [
    '7984907753',
    '7778885383',
    '9712977261',
    // '9081476469',
  ];

  /// Normalizes a phone number to its last 10 digits.
  static String normalizePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Checks if a given phone number belongs to an authorized administrator.
  static bool isAllowedAdminPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final norm = normalizePhone(phone.trim());
    if (norm.isEmpty) return false;
    return allowedAdminPhoneNumbers.any((p) {
      final pNorm = normalizePhone(p);
      return pNorm == norm;
    });
  }
}
