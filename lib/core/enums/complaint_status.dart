import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ComplaintStatus { pending, reviewed, resolved }

extension ComplaintStatusX on ComplaintStatus {
  static ComplaintStatus fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'solved':
      case 'resolved':
      case 'closed':
      case 'auto_closed':
        return ComplaintStatus.resolved;
      case 'reviewed':
      case 'in_progress':
      case 'inprogress':
      case 'in-progress':
        return ComplaintStatus.reviewed;
      case 'pending':
      default:
        return ComplaintStatus.pending;
    }
  }

  String get apiValue {
    switch (this) {
      case ComplaintStatus.pending:
        return 'pending';
      case ComplaintStatus.reviewed:
        return 'in_progress';
      case ComplaintStatus.resolved:
        return 'solved';
    }
  }

  /// "reviewed" is displayed as "Under Review".
  String get label {
    switch (this) {
      case ComplaintStatus.pending:
        return 'Pending';
      case ComplaintStatus.reviewed:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintStatus.pending:
        return AppColors.warningOrange;
      case ComplaintStatus.reviewed:
        return AppColors.pendingBlue;
      case ComplaintStatus.resolved:
        return AppColors.successGreen;
    }
  }
}
