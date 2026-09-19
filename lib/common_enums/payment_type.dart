import 'package:flutter/material.dart';

enum PaymentType { online, cheque, cash }

extension PaymentTypeX on PaymentType {
  static PaymentType fromApi(String value) => PaymentType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PaymentType.online,
  );

  String get apiValue => name;

  String get label {
    switch (this) {
      case PaymentType.online:
        return 'Online';
      case PaymentType.cheque:
        return 'Cheque';
      case PaymentType.cash:
        return 'Cash';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentType.online:
        return Icons.credit_card_outlined;
      case PaymentType.cheque:
        return Icons.receipt_long_outlined;
      case PaymentType.cash:
        return Icons.payments_outlined;
    }
  }
}
