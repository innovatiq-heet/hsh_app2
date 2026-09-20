import '../../../common_enums/payment_type.dart';
import '../../../common_enums/transaction_status.dart';

class FeeSummaryResponse {
  final double totalBilled;
  final double totalApproved;
  final double depositBalance;
  final double netDue;

  const FeeSummaryResponse({
    required this.totalBilled,
    required this.totalApproved,
    required this.depositBalance,
    required this.netDue,
  });
}

class FeeDebitResponse {
  final String id;
  final String label;
  final double amount;
  final String academicYear;
  final DateTime billedAt;

  const FeeDebitResponse({
    required this.id,
    required this.label,
    required this.amount,
    required this.academicYear,
    required this.billedAt,
  });
}

class DepositEntryResponse {
  final String id;
  final double amount;
  final bool isCredit;
  final String narration;
  final DateTime date;

  const DepositEntryResponse({
    required this.id,
    required this.amount,
    required this.isCredit,
    required this.narration,
    required this.date,
  });
}

class FeeTransactionResponse {
  final String id;
  final double amount;
  final PaymentType type;
  final TransactionStatus status;
  final DateTime submittedAt;
  final String? chequeNumber;
  final DateTime? chequeDate;
  final String? bankName;
  final String? narration;
  final String? transactionRef;
  final String? receiptNumber;
  final String? attachmentUrl;

  const FeeTransactionResponse({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.submittedAt,
    this.chequeNumber,
    this.chequeDate,
    this.bankName,
    this.narration,
    this.transactionRef,
    this.receiptNumber,
    this.attachmentUrl,
  });
}
