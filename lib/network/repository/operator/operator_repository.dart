import '../../../common_enums/admission_status.dart';
import '../../../common_enums/leave_status.dart';
import '../../../common_enums/payment_type.dart';
import '../../../common_enums/transaction_status.dart';
import '../../../constants/app_config.dart';
import '../../request/attendance/mark_attendance_request.dart';
import '../../request/fees/submit_payment_request.dart';
import '../../request/operator/operator_requests.dart';
import '../../responses/attendance/attendance_responses.dart';
import '../../responses/fees/fee_responses.dart';
import '../../responses/leave/leave_response.dart';
import '../../responses/operator/operator_responses.dart';

/// Admin/warden (and, for some actions, staff) operator-facing calls.
class OperatorRepository {
  final List<StudentDirectoryItem> _directory = List.generate(37, (i) {
    return StudentDirectoryItem(
      aadhar: '10000000000$i',
      fullName: 'Student ${i + 1}',
      room: 'A-${100 + i}',
      phone: '90000000${i.toString().padLeft(2, '0')}',
      status: i % 11 == 0 ? AdmissionStatus.left : AdmissionStatus.active,
    );
  });

  final List<AdmissionRequest> _pendingAdmissions = [
    AdmissionRequest(
      id: 'adm-1',
      fullName: 'Rohan Mehta',
      email: 'rohan@example.com',
      phone: '9123456780',
      requestedAt: DateTime.now().toUtc().subtract(const Duration(hours: 20)),
    ),
    AdmissionRequest(
      id: 'adm-2',
      fullName: 'Aarav Shah',
      email: 'aarav@example.com',
      phone: '9123456781',
      requestedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    ),
  ];

  final List<LeaveResponse> _pendingLeaves = [
    LeaveResponse(
      id: 'op-leave-1',
      startTime: DateTime.now().toUtc().add(const Duration(days: 1)),
      endTime: DateTime.now().toUtc().add(const Duration(days: 3)),
      reason: 'Family function',
      status: LeaveStatus.pending,
      appliedAt: DateTime.now().toUtc().subtract(const Duration(hours: 10)),
    ),
  ];

  final List<FeeTransactionResponse> _pendingTransactions = [
    FeeTransactionResponse(
      id: 'op-txn-1',
      amount: 5000,
      type: PaymentType.cheque,
      status: TransactionStatus.pending,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(hours: 6)),
      chequeNumber: '000456',
      bankName: 'ICICI Bank',
    ),
  ];

  // --- Directory / Search ---
  Future<List<StudentDirectoryItem>> searchStudents({
    String query = '',
    required int offset,
    required int limit,
  }) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final filtered = query.isEmpty
        ? _directory
        : _directory
              .where(
                (s) =>
                    s.fullName.toLowerCase().contains(query.toLowerCase()) ||
                    s.room.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    if (offset >= filtered.length) return [];
    return filtered.skip(offset).take(limit).toList();
  }

  // --- Admission Approval ---
  Future<List<AdmissionRequest>> pendingAdmissions() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return List.unmodifiable(_pendingAdmissions);
  }

  Future<void> approveAdmission(String id) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    _pendingAdmissions.removeWhere((a) => a.id == id);
  }

  // --- Room Swap ---
  Future<void> swapRooms(RoomSwapRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final aIndex = _directory.indexWhere(
      (s) => s.aadhar == request.studentAadharA,
    );
    final bIndex = _directory.indexWhere(
      (s) => s.aadhar == request.studentAadharB,
    );
    if (aIndex == -1 || bIndex == -1) return;
    final a = _directory[aIndex];
    final b = _directory[bIndex];
    _directory[aIndex] = StudentDirectoryItem(
      aadhar: a.aadhar,
      fullName: a.fullName,
      room: b.room,
      phone: a.phone,
      status: a.status,
    );
    _directory[bIndex] = StudentDirectoryItem(
      aadhar: b.aadhar,
      fullName: b.fullName,
      room: a.room,
      phone: b.phone,
      status: b.status,
    );
  }

  // --- Mark Student Left ---
  Future<void> markStudentLeft(MarkStudentLeftRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final index = _directory.indexWhere(
      (s) => s.aadhar == request.studentAadhar,
    );
    if (index == -1) return;
    final s = _directory[index];
    _directory[index] = StudentDirectoryItem(
      aadhar: s.aadhar,
      fullName: s.fullName,
      room: s.room,
      phone: s.phone,
      status: AdmissionStatus.left,
    );
  }

  // --- Leave Approvals ---
  Future<List<LeaveResponse>> pendingLeaves() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return List.unmodifiable(_pendingLeaves);
  }

  Future<void> decideLeave(String id, {required bool approve}) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    _pendingLeaves.removeWhere((l) => l.id == id);
  }

  // --- Fee Transaction Approvals ---
  Future<List<FeeTransactionResponse>> pendingTransactions() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return List.unmodifiable(_pendingTransactions);
  }

  Future<void> decideTransaction(String id, {required bool approve}) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    _pendingTransactions.removeWhere((t) => t.id == id);
  }

  // --- Deposit & Debit Entry ---
  Future<void> recordDeposit(DepositEntryRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
  }

  Future<void> postFeeDebit(FeeDebitRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
  }

  // --- Sabha Scheduling ---
  final List<SabhaResponse> _sabhas = [];

  Future<SabhaResponse> scheduleSabha(ScheduleSabhaRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final sabha = SabhaResponse(
      id: 'sabha-${_sabhas.length + 100}',
      title: request.title,
      date: request.date,
      startTime: request.startTime,
      endTime: request.endTime,
    );
    _sabhas.add(sabha);
    return sabha;
  }

  // --- Attendance on behalf of ---
  Future<void> logAttendanceOnBehalf(
    MarkAttendanceOnBehalfRequest request,
  ) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
  }
}
