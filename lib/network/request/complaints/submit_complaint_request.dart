import 'dart:io';

/// Aadhar is submitted as part of the complaint form itself, unlike
/// leaves/fees/attendance/laundry where it's silently injected server-side.
class SubmitComplaintRequest {
  final String studentAadhar;
  final String category;
  final String title;
  final String description;
  final List<File> images;

  const SubmitComplaintRequest({
    required this.studentAadhar,
    required this.category,
    required this.title,
    required this.description,
    this.images = const [],
  });
}
