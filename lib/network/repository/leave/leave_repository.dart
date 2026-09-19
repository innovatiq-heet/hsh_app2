import '../../../common_enums/leave_status.dart';
import '../../../constants/app_config.dart';
import '../../request/leave/apply_leave_request.dart';
import '../../responses/leave/leave_response.dart';

class LeaveRepository {
  final List<LeaveResponse> _leaves = [
    LeaveResponse(
      id: 'leave-1',
      startTime: DateTime.now().toUtc().add(const Duration(days: 3)),
      endTime: DateTime.now().toUtc().add(const Duration(days: 5)),
      reason: 'Family function at home town',
      status: LeaveStatus.pending,
      appliedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    ),
    LeaveResponse(
      id: 'leave-2',
      startTime: DateTime.now().toUtc().subtract(const Duration(days: 10)),
      endTime: DateTime.now().toUtc().subtract(const Duration(days: 8)),
      reason: 'Medical checkup',
      status: LeaveStatus.approved,
      appliedAt: DateTime.now().toUtc().subtract(const Duration(days: 12)),
    ),
    LeaveResponse(
      id: 'leave-3',
      startTime: DateTime.now().toUtc().subtract(const Duration(days: 20)),
      endTime: DateTime.now().toUtc().subtract(const Duration(days: 19)),
      reason: 'Personal work',
      status: LeaveStatus.rejected,
      appliedAt: DateTime.now().toUtc().subtract(const Duration(days: 22)),
    ),
  ];

  Future<List<LeaveResponse>> history() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return List.unmodifiable(_leaves);
  }

  Future<LeaveResponse> apply(ApplyLeaveRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final leave = LeaveResponse(
      id: 'leave-${_leaves.length + 1}',
      startTime: request.startTime,
      endTime: request.endTime,
      reason: request.reason,
      status: LeaveStatus.pending,
      appliedAt: DateTime.now().toUtc(),
    );
    _leaves.insert(0, leave);
    return leave;
  }

  /// Server rejects cancelling a non-pending leave — callers should already
  /// gate the delete action on status == pending for a clean UX.
  Future<void> cancel(String id) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    _leaves.removeWhere((l) => l.id == id && l.status == LeaveStatus.pending);
  }
}
