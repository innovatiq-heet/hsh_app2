import '../../../common_enums/complaint_status.dart';
import '../../../common_models/attachments/attachment_model.dart';

class ComplaintResponse {
  final String id;
  final String studentAadhar;
  final String studentName;
  final String room;
  final String category;
  final String title;
  final String description;
  final ComplaintStatus status;
  final DateTime submittedAt;
  final List<AttachmentModel> attachments;
  final String? feedback;

  const ComplaintResponse({
    required this.id,
    required this.studentAadhar,
    required this.studentName,
    required this.room,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.submittedAt,
    this.attachments = const [],
    this.feedback,
  });

  ComplaintResponse copyWith({ComplaintStatus? status, String? feedback}) {
    return ComplaintResponse(
      id: id,
      studentAadhar: studentAadhar,
      studentName: studentName,
      room: room,
      category: category,
      title: title,
      description: description,
      status: status ?? this.status,
      submittedAt: submittedAt,
      attachments: attachments,
      feedback: feedback ?? this.feedback,
    );
  }
}
