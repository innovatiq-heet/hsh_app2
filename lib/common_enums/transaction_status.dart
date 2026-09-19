import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Status of a student-submitted payment slip (fees transactions).
enum TransactionStatus { pending, approved, rejected }

extension TransactionStatusX on TransactionStatus {
  static TransactionStatus fromApi(String value) =>
      TransactionStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TransactionStatus.pending,
      );

  String get apiValue => name;

  String get label {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.approved:
        return 'Approved';
      case TransactionStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case TransactionStatus.pending:
        return AppColors.pendingBlue;
      case TransactionStatus.approved:
        return AppColors.successGreen;
      case TransactionStatus.rejected:
        return AppColors.cancelledRed;
    }
  }
}
