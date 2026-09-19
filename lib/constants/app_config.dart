/// App-wide runtime config. `baseUrl` is a placeholder until real API
/// integration — network/repository/* currently return mock data and never
/// read this value.
class AppConfig {
  AppConfig._();

  static const String baseUrl = 'https://api.hsh-hostel.example.com';
  static const String appName = 'Hari Saurabh Hostel App';
  static const Duration mockNetworkDelay = Duration(milliseconds: 600);
}
