import '../../../common_enums/complaint_status.dart';
import '../../../common_models/attachments/attachment_model.dart';
import '../../../constants/app_config.dart';

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
  final String? review;
  final String? phone;
  final int imagesCount;
  final DateTime? reviewTime;
  final DateTime? resolveTime;

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
    this.review,
    this.phone,
    this.imagesCount = 0,
    this.reviewTime,
    this.resolveTime,
  });

  factory ComplaintResponse.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? '').toString();
    final aadhar = (json['aadhar'] ?? json['studentAadhar'] ?? '').toString();
    final name = (json['fullName'] ?? json['studentName'])?.toString() ??
        (aadhar.isNotEmpty ? 'Student #$aadhar' : 'Unknown Student');
    final room = (json['room'] ?? '').toString();
    final category = (json['compType'] ?? json['category'] ?? 'Other').toString();
    final description = (json['compDesc'] ?? json['description'] ?? '').toString();
    
    // Auto-generate clean title if missing
    String title = (json['title'] ?? '').toString().trim();
    if (title.isEmpty) {
      if (description.isNotEmpty) {
        final firstLine = description.split('\n').first.trim();
        title = firstLine.length > 40 ? '${firstLine.substring(0, 37)}...' : firstLine;
      } else {
        title = '$category Issue';
      }
    }

    final rawStatus = (json['status'] ?? 'pending').toString();
    final status = ComplaintStatusX.fromApi(rawStatus);

    DateTime submittedAt = DateTime.now();
    final rawSubmit = json['submitTime'] ?? json['submittedAt'];
    if (rawSubmit != null) {
      final parsed = DateTime.tryParse(rawSubmit.toString());
      if (parsed != null) submittedAt = parsed;
    }

    DateTime? reviewTime;
    if (json['reviewTime'] != null) {
      reviewTime = DateTime.tryParse(json['reviewTime'].toString());
    }

    DateTime? resolveTime;
    if (json['resolveTime'] != null) {
      resolveTime = DateTime.tryParse(json['resolveTime'].toString());
    }

    final imagesCount = (json['images'] is num)
        ? (json['images'] as num).toInt()
        : (json['imagesCount'] is num ? (json['imagesCount'] as num).toInt() : 0);

    final feedback = (json['response'] ?? json['feedback'])?.toString();
    final review = json['review']?.toString();
    final phone = json['phone']?.toString();

    List<AttachmentModel> attachments = const [];
    if (json['attachments'] is List) {
      attachments = (json['attachments'] as List)
          .map((a) => a is AttachmentModel ? a : null)
          .whereType<AttachmentModel>()
          .toList();
    } else if (imagesCount > 0 && rawId.isNotEmpty) {
      // The backend never returns a URL list — createComplain() only tracks
      // an image *count* on the row — but it renames uploads to a fixed,
      // predictable pattern (complain_<id>_<index>.<ext>) and serves them
      // statically from /uploads (see complain.service.ts, server.ts). Our
      // own upload always sends `.jpg` filenames (ComplaintsRepository.
      // submit), so that's the extension the server ends up storing under.
      attachments = List.generate(
        imagesCount,
        (index) => AttachmentModel(
          url: '${AppConfig.mediaBaseUrl}/uploads/complains/complain_${rawId}_$index.jpg',
        ),
      );
    }

    return ComplaintResponse(
      id: rawId,
      studentAadhar: aadhar,
      studentName: name,
      room: room,
      category: category,
      title: title,
      description: description,
      status: status,
      submittedAt: submittedAt,
      attachments: attachments,
      feedback: feedback,
      review: review,
      phone: phone,
      imagesCount: imagesCount,
      reviewTime: reviewTime,
      resolveTime: resolveTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'aadhar': studentAadhar,
      'studentAadhar': studentAadhar,
      'fullName': studentName,
      'studentName': studentName,
      'room': room,
      'compType': category,
      'category': category,
      'title': title,
      'compDesc': description,
      'description': description,
      'status': status.apiValue,
      'submitTime': submittedAt.toIso8601String(),
      'submittedAt': submittedAt.toIso8601String(),
      'response': feedback,
      'feedback': feedback,
      'review': review,
      'phone': phone,
      'images': imagesCount,
      'imagesCount': imagesCount,
      'reviewTime': reviewTime?.toIso8601String(),
      'resolveTime': resolveTime?.toIso8601String(),
    };
  }

  ComplaintResponse copyWith({
    String? id,
    String? studentAadhar,
    String? studentName,
    String? room,
    String? category,
    String? title,
    String? description,
    ComplaintStatus? status,
    DateTime? submittedAt,
    List<AttachmentModel>? attachments,
    String? feedback,
    String? review,
    String? phone,
    int? imagesCount,
    DateTime? reviewTime,
    DateTime? resolveTime,
  }) {
    return ComplaintResponse(
      id: id ?? this.id,
      studentAadhar: studentAadhar ?? this.studentAadhar,
      studentName: studentName ?? this.studentName,
      room: room ?? this.room,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      attachments: attachments ?? this.attachments,
      feedback: feedback ?? this.feedback,
      review: review ?? this.review,
      phone: phone ?? this.phone,
      imagesCount: imagesCount ?? this.imagesCount,
      reviewTime: reviewTime ?? this.reviewTime,
      resolveTime: resolveTime ?? this.resolveTime,
    );
  }
}
