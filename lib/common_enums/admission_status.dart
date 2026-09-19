import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Student admission/account lifecycle state, used by the operator
/// directory and admission-approval screens.
enum AdmissionStatus { pendingApproval, active, left }

extension AdmissionStatusX on AdmissionStatus {
  String get label {
    switch (this) {
      case AdmissionStatus.pendingApproval:
        return 'Pending Approval';
      case AdmissionStatus.active:
        return 'Active';
      case AdmissionStatus.left:
        return 'Left';
    }
  }

  Color get color {
    switch (this) {
      case AdmissionStatus.pendingApproval:
        return AppColors.warningOrange;
      case AdmissionStatus.active:
        return AppColors.successGreen;
      case AdmissionStatus.left:
        return AppColors.textMuted;
    }
  }
}
