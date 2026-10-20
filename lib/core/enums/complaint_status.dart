import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Room complaint lifecycle (`complaints.status`). Solvers may move a
/// complaint from any status to any other; students only read it.
enum ComplaintStatus { open, inProgress, resolved, closed }

extension ComplaintStatusX on ComplaintStatus {
  static ComplaintStatus fromApi(String? value) {
    switch (value?.toUpperCase().trim()) {
      case 'IN_PROGRESS':
        return ComplaintStatus.inProgress;
      case 'RESOLVED':
        return ComplaintStatus.resolved;
      case 'CLOSED':
        return ComplaintStatus.closed;
      case 'OPEN':
      default:
        return ComplaintStatus.open;
    }
  }

  String get apiValue {
    switch (this) {
      case ComplaintStatus.open:
        return 'OPEN';
      case ComplaintStatus.inProgress:
        return 'IN_PROGRESS';
      case ComplaintStatus.resolved:
        return 'RESOLVED';
      case ComplaintStatus.closed:
        return 'CLOSED';
    }
  }

  /// Student-facing label ("OPEN" reads as "Submitted").
  String get label {
    switch (this) {
      case ComplaintStatus.open:
        return 'Submitted';
      case ComplaintStatus.inProgress:
        return 'In progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.closed:
        return 'Closed';
    }
  }

  /// Solver-facing label used on the queue tabs.
  String get staffLabel => this == ComplaintStatus.open ? 'Open' : label;

  Color get color {
    switch (this) {
      case ComplaintStatus.open:
        return AppColors.warningOrange;
      case ComplaintStatus.inProgress:
        return AppColors.pendingBlue;
      case ComplaintStatus.resolved:
        return AppColors.successGreen;
      case ComplaintStatus.closed:
        return AppColors.textSecondary;
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintStatus.open:
        return Icons.hourglass_top_rounded;
      case ComplaintStatus.inProgress:
        return Icons.build_circle_outlined;
      case ComplaintStatus.resolved:
        return Icons.check_circle_outline_rounded;
      case ComplaintStatus.closed:
        return Icons.lock_outline_rounded;
    }
  }
}
