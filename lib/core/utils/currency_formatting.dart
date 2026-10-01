import 'package:intl/intl.dart';

/// Rupee amounts with Indian digit grouping (₹1,20,000).
class Money {
  Money._();

  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String format(double amount) => _inr.format(amount);
}
