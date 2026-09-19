import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum LeaveStatus { pending, approved, rejected }

extension LeaveStatusX on LeaveStatus {
  static LeaveStatus fromApi(String value) => LeaveStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => LeaveStatus.pending,
  );

  String get apiValue => name;

  String get label {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case LeaveStatus.pending:
        return AppColors.pendingBlue;
      case LeaveStatus.approved:
        return AppColors.successGreen;
      case LeaveStatus.rejected:
        return AppColors.cancelledRed;
    }
  }
}
