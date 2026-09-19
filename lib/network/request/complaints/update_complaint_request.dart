import '../../../common_enums/complaint_status.dart';

class UpdateComplaintRequest {
  final ComplaintStatus? status;
  final String? response;
  final String? review;
  final String? user;

  const UpdateComplaintRequest({
    this.status,
    this.response,
    this.review,
    this.user,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (status != null) map['status'] = status!.apiValue;
    if (response != null) map['response'] = response;
    if (review != null) map['review'] = review;
    if (user != null) map['user'] = user;
    return map;
  }
}
