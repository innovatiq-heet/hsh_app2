/// App-wide runtime configuration.
///
/// All constants here are compile-time values so they can be `const` and
/// inlined by the compiler. Swap [baseUrl] for a real host before release.
class AppConfig {
  AppConfig._();

  static const String host = 'https://hshbackend.hpys.in';
  static const String baseUrl = 'https://hshbackend.hpys.in/api';
  static const String healthUrl = 'https://hshbackend.hpys.in/';

  /// Live hosted attendance schedule endpoint.
  static const String attendanceScheduleUrl =
      'https://attendentsnews.hpys.in/api/schedule-data';

  /// External student basic-details endpoint.
  static const String studentBasicDetailsUrl =
      'https://api.avdvvn.org/public/getStudentBasicDetails';
  static const String studentBasicDetailsAuthToken = 'aF92Kx7QmN4Lp8Vz';

  /// Server origin without the `/api` prefix — statically served uploads
  /// (e.g. complaint photos mounted at `/uploads`) live here, not under `/api`.
  static String get mediaBaseUrl => baseUrl.endsWith('/api')
      ? baseUrl.substring(0, baseUrl.length - 4)
      : baseUrl;

  /// Artificial delay used in repositories that serve mock/local data.
  static const Duration mockNetworkDelay = Duration(milliseconds: 600);

  /// Authorized mobile numbers permitted to log in as Admin.
  static const List<String> allowedAdminPhoneNumbers = [
    '7984907753',
    '7778885383',
    '9081476469',
  ];

  /// Checks if a given phone number belongs to an authorized administrator.
  static bool isAllowedAdminPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final norm = digits.length >= 10
        ? digits.substring(digits.length - 10)
        : digits;
    return allowedAdminPhoneNumbers.any((p) {
      final pDigits = p.replaceAll(RegExp(r'\D'), '');
      final pNorm = pDigits.length >= 10
          ? pDigits.substring(pDigits.length - 10)
          : pDigits;
      return pNorm == norm;
    });
  }
}
