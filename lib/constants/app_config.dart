/// App-wide runtime config.
class AppConfig {
  AppConfig._();

  /// Dev backend on the LAN — reachable from a real device on the same
  /// Wi-Fi and from the Android emulator (which routes host-machine IPs
  /// through normally, unlike `localhost`/`10.0.2.2` special-casing).
  /// Swap this for a real host before release.
  static const String host = 'http://192.168.29.7:5000';
  static const String baseUrl = 'http://192.168.29.7:5000/api';
  static const String healthUrl = 'http://192.168.29.7:5000/health';

  static const String appName = 'Hari Saurabh Hostel App';
  static const Duration mockNetworkDelay = Duration(milliseconds: 600);
}
