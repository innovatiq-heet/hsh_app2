import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../common_enums/laundry_status.dart';
import '../../../constants/app_config.dart';
import '../../api_client.dart';
import '../../request/laundry/submit_laundry_request.dart';
import '../../responses/laundry/laundry_responses.dart';

class LaundryRepository {
  final Dio _dio = Get.find<ApiClient>().dio;
  double _balance = 350;

  final List<LaundryTicketResponse> _tickets = [
    LaundryTicketResponse(
      id: 'lt-1',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      itemCount: 6,
      totalAmount: 60,
      status: LaundryStatus.received,
      submittedAt: DateTime.now().toUtc().subtract(
        const Duration(days: 5, hours: 2),
      ),
      acceptedAt: DateTime.now().toUtc().subtract(
        const Duration(days: 5, hours: 1),
      ),
      washedAt: DateTime.now().toUtc().subtract(
        const Duration(days: 4, hours: 3),
      ),
      receivedAt: DateTime.now().toUtc().subtract(
        const Duration(days: 3, hours: 6),
      ),
    ),
    LaundryTicketResponse(
      id: 'lt-2',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      itemCount: 4,
      totalAmount: 40,
      status: LaundryStatus.washed,
      submittedAt: DateTime.now().toUtc().subtract(
        const Duration(days: 1, hours: 4),
      ),
      acceptedAt: DateTime.now().toUtc().subtract(
        const Duration(days: 1, hours: 2),
      ),
      washedAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
    ),
    LaundryTicketResponse(
      id: 'lt-3',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      itemCount: 3,
      totalAmount: 30,
      status: LaundryStatus.pending,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    ),
  ];

  /// Calls GET /laundry/balance — the backend auto-resolves the student's
  /// aadhar from the JWT email, so no aadhar param is needed.
  /// Also used as the secondary aadhar-resolver fallback by AadharResolvingMixin.
  Future<LaundryBalanceResponse> balance() async {
    try {
      final response = await _dio.get('/laundry/balance');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final bal = payload['balance'];
          if (bal is Map<String, dynamic>) {
            return LaundryBalanceResponse(
              studentAadhar: bal['aadhar']?.toString() ?? '',
              balance: (bal['balance'] as num?)?.toDouble() ?? 0,
            );
          }
        }
      }
      return LaundryBalanceResponse(studentAadhar: '', balance: _balance);
    } on DioException {
      // Fallback to cached local balance on network failure.
      return LaundryBalanceResponse(studentAadhar: '', balance: _balance);
    } catch (_) {
      return LaundryBalanceResponse(studentAadhar: '', balance: _balance);
    }
  }

  Future<List<LaundryTicketResponse>> tickets() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return List.unmodifiable(_tickets);
  }

  Future<LaundryTicketResponse> ticketDetail(String id) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return _tickets.firstWhere((t) => t.id == id);
  }

  Future<LaundryTicketResponse> submit(SubmitLaundryRequest request) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final ticket = LaundryTicketResponse(
      id: 'lt-${_tickets.length + 1}',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      itemCount: request.itemCount,
      totalAmount: request.itemCount * 10,
      status: LaundryStatus.pending,
      submittedAt: DateTime.now().toUtc(),
    );
    _tickets.insert(0, ticket);
    return ticket;
  }

  // --- Operator-facing (staff/warden/admin shared) ---

  Future<double> recharge(String studentAadhar, double amount) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    _balance += amount;
    return _balance;
  }

  Future<LaundryTicketResponse> advanceStatus(String ticketId) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    final ticket = _tickets[index];
    final nextIndex = (ticket.status.stageIndex + 1).clamp(
      0,
      LaundryStatus.values.length - 1,
    );
    final next = LaundryStatus.values[nextIndex];
    final now = DateTime.now().toUtc();
    final updated = LaundryTicketResponse(
      id: ticket.id,
      studentName: ticket.studentName,
      room: ticket.room,
      itemCount: ticket.itemCount,
      totalAmount: ticket.totalAmount,
      status: next,
      submittedAt: ticket.submittedAt,
      acceptedAt: next == LaundryStatus.accepted ? now : ticket.acceptedAt,
      washedAt: next == LaundryStatus.washed ? now : ticket.washedAt,
      receivedAt: next == LaundryStatus.received ? now : ticket.receivedAt,
    );
    _tickets[index] = updated;
    return updated;
  }
}
