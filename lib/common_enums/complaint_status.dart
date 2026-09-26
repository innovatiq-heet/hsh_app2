import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ComplaintStatus { pending, reviewed, resolved }

extension ComplaintStatusX on ComplaintStatus {
  static ComplaintStatus fromApi(String value) {
    final v = value.toLowerCase().trim();
    if (v == 'in_progress' || v == 'reviewed' || v == 'processing' || v == 'investigating') {
      return ComplaintStatus.reviewed;
    }
    if (v == 'resolved' || v == 'solved' || v == 'closed' || v == 'auto_closed') {
      return ComplaintStatus.resolved;
    }
    return ComplaintStatus.pending;
  }

  String get apiValue => name;

  /// "reviewed" is displayed as "Under Review".
  String get label {
    switch (this) {
      case ComplaintStatus.pending:
        return 'Pending';
      case ComplaintStatus.reviewed:
        return 'Under Review';
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
