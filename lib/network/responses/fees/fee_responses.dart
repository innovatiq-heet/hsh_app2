import 'package:get/get.dart';
import '../../../common_enums/payment_type.dart';
import '../../../common_enums/transaction_status.dart';

class FeeSummaryResponse {
  final String? aadhar;
  final double totalFeeDebits;
  final double totalApprovedPayments;
  final double totalDepositCredit;
  final double totalDepositDebit;
  final double depositBalance;
  final double netDue;

  const FeeSummaryResponse({
    this.aadhar,
    required this.totalFeeDebits,
    required this.totalApprovedPayments,
    this.totalDepositCredit = 0.0,
    this.totalDepositDebit = 0.0,
    required this.depositBalance,
    required this.netDue,
  });

  // UI-friendly backwards compatibility getters
  double get totalBilled => totalFeeDebits;
  double get totalApproved => totalApprovedPayments;

  factory FeeSummaryResponse.fromJson(Map<String, dynamic> json) {
    final debits = (json['totalFeeDebits'] as num?)?.toDouble() ??
        (json['totalBilled'] as num?)?.toDouble() ??
        0.0;
    final approved = (json['totalApprovedPayments'] as num?)?.toDouble() ??
        (json['totalApproved'] as num?)?.toDouble() ??
        0.0;
    final depCredit = (json['totalDepositCredit'] as num?)?.toDouble() ?? 0.0;
    final depDebit = (json['totalDepositDebit'] as num?)?.toDouble() ?? 0.0;
    final depBal = (json['depositBalance'] as num?)?.toDouble() ??
        (depCredit - depDebit);
    final net = (json['netDue'] as num?)?.toDouble() ?? (debits - approved);

    return FeeSummaryResponse(
      aadhar: json['aadhar']?.toString(),
      totalFeeDebits: debits,
      totalApprovedPayments: approved,
      totalDepositCredit: depCredit,
      totalDepositDebit: depDebit,
      depositBalance: depBal,
      netDue: net,
    );
  }
}

class FeeDebitResponse {
  final String id;
  final String label;
  final double amount;
  final String academicYear;
  final DateTime billedAt;
  final String? aadhar;
  final int? year;
  final String? type;
  final String? narration;

  const FeeDebitResponse({
    required this.id,
    required this.label,
    required this.amount,
    required this.academicYear,
    required this.billedAt,
    this.aadhar,
    this.year,
    this.type,
    this.narration,
  });

  factory FeeDebitResponse.fromJson(Map<String, dynamic> json) {
    final rawAmount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final rawYear = json['year'] is num
        ? (json['year'] as num).toInt()
        : int.tryParse(json['year']?.toString() ?? '');
    final typeStr = json['type']?.toString();
    final narrationStr = json['narration']?.toString();

    String computedLabel;
    if (narrationStr != null && narrationStr.trim().isNotEmpty) {
      computedLabel = narrationStr.trim();
    } else if (typeStr != null && typeStr.trim().isNotEmpty) {
      computedLabel = typeStr.trim().capitalizeFirst ?? typeStr.trim();
    } else {
      computedLabel = json['label']?.toString() ?? 'Fee Debit';
    }

    String computedYear;
    if (json['academicYear'] != null &&
        json['academicYear'].toString().isNotEmpty) {
      computedYear = json['academicYear'].toString();
    } else if (rawYear != null) {
      computedYear = 'Year $rawYear';
    } else {
      computedYear = 'General';
    }

    final billed = DateTime.tryParse(
          json['time']?.toString() ?? json['billedAt']?.toString() ?? '',
        ) ??
        DateTime.now();

    return FeeDebitResponse(
      id: json['id']?.toString() ?? '',
      label: computedLabel,
      amount: rawAmount,
      academicYear: computedYear,
      billedAt: billed,
      aadhar: json['aadhar']?.toString(),
      year: rawYear,
      type: typeStr,
      narration: narrationStr,
    );
  }
}

class DepositEntryResponse {
  final String id;
  final double amount;
  final bool isCredit;
  final String narration;
  final DateTime date;
  final String? aadhar;
  final int? year;

  const DepositEntryResponse({
    required this.id,
    required this.amount,
    required this.isCredit,
    required this.narration,
    required this.date,
    this.aadhar,
    this.year,
  });

  factory DepositEntryResponse.fromJson(Map<String, dynamic> json) {
    final rawAmount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final creditOrDebit = json['creditOrDebit']?.toString().toLowerCase();
    final isCredit = creditOrDebit == 'credit' || json['isCredit'] == true;
    final narrationStr = json['narration']?.toString() ??
        (isCredit ? 'Security Deposit' : 'Deposit Deduction');
    final date = DateTime.tryParse(
          json['time']?.toString() ?? json['date']?.toString() ?? '',
        ) ??
        DateTime.now();
    final rawYear = json['year'] is num
        ? (json['year'] as num).toInt()
        : int.tryParse(json['year']?.toString() ?? '');

    return DepositEntryResponse(
      id: json['id']?.toString() ?? '',
      amount: rawAmount,
      isCredit: isCredit,
      narration: narrationStr,
      date: date,
      aadhar: json['aadhar']?.toString(),
      year: rawYear,
    );
  }
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
  final DateTime? approveTime;
  final String? rejectReason;
  final String? aadhar;

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
    this.approveTime,
    this.rejectReason,
    this.aadhar,
  });

  factory FeeTransactionResponse.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final rawAmount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final rawType = json['paymentType']?.toString() ??
        json['type']?.toString() ??
        'online';
    final paymentType = PaymentTypeX.fromApi(rawType);
    final rawStatus = json['status']?.toString() ?? 'pending';
    final status = TransactionStatusX.fromApi(rawStatus);

    final submitted = DateTime.tryParse(
          json['time']?.toString() ?? json['submittedAt']?.toString() ?? '',
        ) ??
        DateTime.now();
    final chqDate = json['chequeDate'] != null
        ? DateTime.tryParse(json['chequeDate'].toString())
        : null;
    final appTime = json['approveTime'] != null
        ? DateTime.tryParse(json['approveTime'].toString())
        : null;

    final narration = json['narration']?.toString();
    String? txRef = json['transactionRef']?.toString();
    if (txRef == null && narration != null) {
      final match = RegExp(r'Ref:\s*([A-Za-z0-9_\-]+)').firstMatch(narration);
      if (match != null) {
        txRef = match.group(1);
      }
    }

    final receipt = json['receiptNumber']?.toString() ?? 'HSH-REC-$id';

    return FeeTransactionResponse(
      id: id,
      amount: rawAmount,
      type: paymentType,
      status: status,
      submittedAt: submitted,
      chequeNumber: json['chequeNumber']?.toString(),
      chequeDate: chqDate,
      bankName: json['bankName']?.toString(),
      narration: narration,
      transactionRef: txRef,
      receiptNumber: receipt,
      attachmentUrl: json['attachmentUrl']?.toString(),
      approveTime: appTime,
      rejectReason: json['rejectReason']?.toString(),
      aadhar: json['aadhar']?.toString(),
    );
  }
}
