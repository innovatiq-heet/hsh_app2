import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Four stages, each backed by its own timestamp on the ticket
/// (submit/accept/wash/receive).
enum LaundryStatus { pending, accepted, washed, received }

extension LaundryStatusX on LaundryStatus {
  static LaundryStatus fromApi(String value) => LaundryStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => LaundryStatus.pending,
  );

  String get apiValue => name;

  String get label {
    switch (this) {
      case LaundryStatus.pending:
        return 'Pending';
      case LaundryStatus.accepted:
        return 'Accepted';
      case LaundryStatus.washed:
        return 'Washed';
      case LaundryStatus.received:
        return 'Received';
    }
  }

  Color get color {
    switch (this) {
      case LaundryStatus.pending:
        return AppColors.warningOrange;
      case LaundryStatus.accepted:
        return AppColors.pendingBlue;
      case LaundryStatus.washed:
        return AppColors.secondary;
      case LaundryStatus.received:
        return AppColors.successGreen;
    }
  }

  int get stageIndex => LaundryStatus.values.indexOf(this);
}
