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
  final String? aadhar;

  const SubmitPaymentRequest({
    required this.amount,
    required this.type,
    this.chequeNumber,
    this.chequeDate,
    this.bankName,
    this.narration,
    this.transactionRef,
    this.attachmentPath,
    this.aadhar,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'amount': amount,
      'paymentType': type.name, // online, cheque, cash
    };

    if (bankName != null && bankName!.trim().isNotEmpty) {
      map['bankName'] = bankName!.trim();
    }

    String? effectiveNarration = narration?.trim();
    if (transactionRef != null && transactionRef!.trim().isNotEmpty) {
      final refStr = 'Ref: ${transactionRef!.trim()}';
      if (effectiveNarration == null || effectiveNarration.isEmpty) {
        effectiveNarration = refStr;
      } else if (!effectiveNarration.contains(transactionRef!.trim())) {
        effectiveNarration = '$effectiveNarration ($refStr)';
      }
    }
    if (effectiveNarration != null && effectiveNarration.isNotEmpty) {
      map['narration'] = effectiveNarration;
    }

    if (type == PaymentType.cheque) {
      if (chequeNumber != null && chequeNumber!.trim().isNotEmpty) {
        map['chequeNumber'] = chequeNumber!.trim();
      }
      if (chequeDate != null) {
        map['chequeDate'] = chequeDate!.toUtc().toIso8601String();
      }
    }

    if (aadhar != null && aadhar!.trim().isNotEmpty) {
      map['aadhar'] = aadhar!.trim();
    }

    return map;
  }
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
