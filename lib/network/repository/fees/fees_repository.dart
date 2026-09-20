import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../common_enums/payment_type.dart';
import '../../../common_enums/transaction_status.dart';
import '../../../constants/app_config.dart';
import '../../api_client.dart';
import '../../request/fees/submit_payment_request.dart';
import '../../responses/fees/fee_responses.dart';

class FeesRepository {
  final Dio _dio = Get.find<ApiClient>().dio;

  final List<FeeTransactionResponse> _transactions = [
    FeeTransactionResponse(
      id: 'txn-1',
      receiptNumber: 'HSH-REC-2026-0891',
      amount: 15000,
      type: PaymentType.online,
      status: TransactionStatus.approved,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
      transactionRef: 'UPI/524391823910/ICICI',
      bankName: 'Google Pay · ICICI Bank',
      narration: 'Term 1 Hostel & Room charges',
    ),
    FeeTransactionResponse(
      id: 'txn-2',
      receiptNumber: 'HSH-REC-2026-1044',
      amount: 5000,
      type: PaymentType.cheque,
      status: TransactionStatus.pending,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      chequeNumber: '000123',
      chequeDate: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      bankName: 'HDFC Bank (Navrangpura)',
      narration: 'Mess & Maintenance advance',
    ),
    FeeTransactionResponse(
      id: 'txn-3',
      receiptNumber: 'HSH-REC-2025-0720',
      amount: 75000,
      type: PaymentType.online,
      status: TransactionStatus.approved,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 180)),
      transactionRef: 'NEFT/CMS291038102/AXIS',
      bankName: 'Axis Bank NetBanking',
      narration: 'Annual Accommodation Fee 2025-26',
    ),
  ];

  /// Bootstrap aadhar resolver — `GET /fees/summary` also happens to be the
  /// endpoint the JWT's student aadhar comes back on (API_HANDOFF.md §8.1),
  /// so this doubles as the primary source for [AadharResolvingMixin].
  /// Returns `null` on failure rather than throwing — the mixin falls back
  /// to the laundry-balance call.
  Future<String?> resolveAadhar() async {
    try {
      final response = await _dio.get('/fees/summary');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final summary = payload['summary'];
          if (summary is Map<String, dynamic>) {
            final aadhar = summary['aadhar']?.toString();
            if (aadhar != null && aadhar.isNotEmpty) {
              return aadhar;
            }
          }
        }
      }
      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<FeeSummaryResponse> summary() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return const FeeSummaryResponse(
      totalBilled: 120000,
      totalApproved: 95000,
      depositBalance: 10000,
      netDue: 25000,
    );
  }

  Future<List<FeeDebitResponse>> debits({String? academicYear}) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final all = [
      FeeDebitResponse(
        id: 'd1',
        label: 'Hostel Fee',
        amount: 80000,
        academicYear: '2025-26',
        billedAt: DateTime.now().toUtc().subtract(const Duration(days: 90)),
      ),
      FeeDebitResponse(
        id: 'd2',
        label: 'Electricity',
        amount: 5000,
        academicYear: '2025-26',
        billedAt: DateTime.now().toUtc().subtract(const Duration(days: 40)),
      ),
      FeeDebitResponse(
        id: 'd3',
        label: 'Maintenance',
        amount: 3000,
        academicYear: '2025-26',
        billedAt: DateTime.now().toUtc().subtract(const Duration(days: 20)),
      ),
      FeeDebitResponse(
        id: 'd4',
        label: 'Damages',
        amount: 2000,
        academicYear: '2024-25',
        billedAt: DateTime.now().toUtc().subtract(const Duration(days: 400)),
      ),
      FeeDebitResponse(
        id: 'd5',
        label: 'Hostel Fee',
        amount: 75000,
        academicYear: '2024-25',
        billedAt: DateTime.now().toUtc().subtract(const Duration(days: 450)),
      ),
    ];
    if (academicYear == null) return all;
    return all.where((e) => e.academicYear == academicYear).toList();
  }

  Future<List<DepositEntryResponse>> deposits() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return [
      DepositEntryResponse(
        id: 'dep1',
        amount: 15000,
        isCredit: true,
        narration: 'Initial security deposit',
        date: DateTime.now().toUtc().subtract(const Duration(days: 200)),
      ),
      DepositEntryResponse(
        id: 'dep2',
        amount: 5000,
        isCredit: false,
        narration: 'Damage deduction',
        date: DateTime.now().toUtc().subtract(const Duration(days: 60)),
      ),
    ];
  }

  Future<List<FeeTransactionResponse>> transactions() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return List.unmodifiable(_transactions);
  }

  Future<FeeTransactionResponse> submitPayment(
    SubmitPaymentRequest request,
  ) async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    final txn = FeeTransactionResponse(
      id: 'txn-${_transactions.length + 1}',
      receiptNumber:
          'HSH-REC-2026-${(1000 + _transactions.length + 1).toString()}',
      amount: request.amount,
      type: request.type,
      status: TransactionStatus.pending,
      submittedAt: DateTime.now().toUtc(),
      chequeNumber: request.chequeNumber,
      chequeDate: request.chequeDate,
      bankName: request.bankName,
      narration: request.narration,
      transactionRef: request.transactionRef,
      attachmentUrl: request.attachmentPath,
    );
    _transactions.insert(0, txn);
    return txn;
  }
}
