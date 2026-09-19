import '../../../common_enums/payment_type.dart';
import '../../../common_enums/transaction_status.dart';
import '../../../constants/app_config.dart';
import '../../request/fees/submit_payment_request.dart';
import '../../responses/fees/fee_responses.dart';

class FeesRepository {
  final List<FeeTransactionResponse> _transactions = [
    FeeTransactionResponse(
      id: 'txn-1',
      amount: 15000,
      type: PaymentType.online,
      status: TransactionStatus.approved,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
    ),
    FeeTransactionResponse(
      id: 'txn-2',
      amount: 5000,
      type: PaymentType.cheque,
      status: TransactionStatus.pending,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      chequeNumber: '000123',
      chequeDate: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      bankName: 'HDFC Bank',
    ),
  ];

  Future<String> resolveAadhar() async {
    await Future.delayed(AppConfig.mockNetworkDelay);
    return '123456789012';
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
      amount: request.amount,
      type: request.type,
      status: TransactionStatus.pending,
      submittedAt: DateTime.now().toUtc(),
      chequeNumber: request.chequeNumber,
      chequeDate: request.chequeDate,
      bankName: request.bankName,
      narration: request.narration,
    );
    _transactions.insert(0, txn);
    return txn;
  }
}
