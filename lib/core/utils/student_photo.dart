import '../constants/app_config.dart';

/// Whose photo: the student's own, or one of their parents'.
enum PhotoOf { student, father, mother }

/// A student's public photo: `<base>/<12-digit Aadhar>.jpg`. Null unless
/// [aadhar] has exactly 12 digits (a four-digit bank code never qualifies).
String? studentPhotoUrl(String? aadhar) => familyPhotoUrl(aadhar, PhotoOf.student);

/// The photo of the student or a parent. Parent photos are named after the
/// **student's** Aadhar too (`father/personal/<student aadhar>.jpg`), so
/// [studentAadhar] is always the student's. Null unless it has 12 digits.
String? familyPhotoUrl(String? studentAadhar, PhotoOf who) {
  final digits = (studentAadhar ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length != 12) return null;
  return '${AppConfig.photoStorageUrl}/${who.name}/personal/$digits.jpg';
}
