import 'package:get/get.dart';

/// What the app-requests banner reads: the directory controller (every
/// student's pending requests) and a student's own controller (that student's
/// requests) both provide it.
abstract interface class AppRequestsHost {
  RxList<Map<String, dynamic>> get pendingAppRequests;
  Future<void> reviewAppRequest(int requestId, String action, {int durationMinutes});
}
