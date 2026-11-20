import '../constants/app_config.dart';

/// A student's public photo: `<base>/<12-digit Aadhar>.jpg`. Null unless
/// [aadhar] has exactly 12 digits (a four-digit bank code never qualifies).
String? studentPhotoUrl(String? aadhar) {
  final digits = (aadhar ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length == 12 ? '${AppConfig.studentPhotoBaseUrl}/$digits.jpg' : null;
}
