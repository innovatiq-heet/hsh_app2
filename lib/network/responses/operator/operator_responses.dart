import '../../../common_enums/admission_status.dart';

class StudentDirectoryItem {
  final String aadhar;
  final String fullName;
  final String room;
  final String phone;
  final AdmissionStatus status;

  const StudentDirectoryItem({
    required this.aadhar,
    required this.fullName,
    required this.room,
    required this.phone,
    required this.status,
  });
}

class AdmissionRequest {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final DateTime requestedAt;

  const AdmissionRequest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.requestedAt,
  });
}
