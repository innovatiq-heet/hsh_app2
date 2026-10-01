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
}
