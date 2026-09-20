import '../../../common_enums/payment_type.dart';

class SubmitPaymentRequest {
  final double amount;
  final PaymentType type;
  final String? chequeNumber;
  final DateTime? chequeDate;
  final String? bankName;
  final String? narration;
  final String? transactionRef;
  final String? attachmentPath;

  const SubmitPaymentRequest({
    required this.amount,
    required this.type,
    this.chequeNumber,
    this.chequeDate,
    this.bankName,
    this.narration,
    this.transactionRef,
    this.attachmentPath,
  });
}

/// Operator-side: record a security deposit credit/debit.
class DepositEntryRequest {
  final String studentAadhar;
  final double amount;
  final bool isCredit;
  final String narration;

  const DepositEntryRequest({
    required this.studentAadhar,
    required this.amount,
    required this.isCredit,
    required this.narration,
  });
}

/// Operator-side: post a new billed charge to a student's ledger.
class FeeDebitRequest {
  final String studentAadhar;
  final String label;
  final double amount;
  final String academicYear;

  const FeeDebitRequest({
    required this.studentAadhar,
    required this.label,
    required this.amount,
    required this.academicYear,
  });
}
