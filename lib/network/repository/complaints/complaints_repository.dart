import '../../../common_enums/complaint_status.dart';
import '../../../common_models/attachments/attachment_model.dart';
import '../../../constants/app_config.dart';
import '../../request/complaints/submit_complaint_request.dart';
import '../../responses/complaints/complaint_response.dart';

class ComplaintsRepository {
  final List<ComplaintResponse> _complaints = [
    ComplaintResponse(
      id: 'c1',
      studentAadhar: '123456789012',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      category: 'Electrical',
      title: 'Fan not working',
      description:
          'The ceiling fan in my room has stopped working since yesterday.',
      status: ComplaintStatus.pending,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
    ),
    ComplaintResponse(
      id: 'c2',
      studentAadhar: '123456789012',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      category: 'Plumbing',
      title: 'Leaking tap',
      description: 'Washroom tap is leaking continuously.',
      status: ComplaintStatus.reviewed,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    ),
    ComplaintResponse(
      id: 'c3',
      studentAadhar: '123456789012',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      category: 'Furniture',
      title: 'Broken chair',
      description: 'Study chair leg is broken.',
      status: ComplaintStatus.resolved,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 10)),
      feedback: 'Replaced with a new chair.',
    ),
  ];

  Future<List<String>> categories() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return [
      'Electrical',
      'Plumbing',
      'Furniture',
      'Housekeeping',
      'Internet/Wifi',
      'Other',
    ];
  }

  Future<List<ComplaintResponse>> list({String? studentAadhar}) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    if (studentAadhar == null) return List.unmodifiable(_complaints);
    return _complaints.where((c) => c.studentAadhar == studentAadhar).toList();
  }

  Future<ComplaintResponse> detail(String id) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return _complaints.firstWhere((c) => c.id == id);
  }

  Future<ComplaintResponse> submit(SubmitComplaintRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final complaint = ComplaintResponse(
      id: 'c${_complaints.length + 1}',
      studentAadhar: request.studentAadhar,
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      category: request.category,
      title: request.title,
      description: request.description,
      status: ComplaintStatus.pending,
      submittedAt: DateTime.now().toUtc(),
      attachments: request.images.map((f) => AttachmentModel(file: f)).toList(),
    );
    _complaints.insert(0, complaint);
    return complaint;
  }

  Future<ComplaintResponse> updateStatus(
    String id,
    ComplaintStatus status,
  ) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final index = _complaints.indexWhere((c) => c.id == id);
    final updated = _complaints[index].copyWith(status: status);
    _complaints[index] = updated;
    return updated;
  }

  Future<ComplaintResponse> addFeedback(String id, String feedback) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final index = _complaints.indexWhere((c) => c.id == id);
    final updated = _complaints[index].copyWith(
      feedback: feedback,
      status: ComplaintStatus.resolved,
    );
    _complaints[index] = updated;
    return updated;
  }
}
