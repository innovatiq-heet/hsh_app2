/// Centralized form validators — used by every form in the app instead of
/// each screen redefining its own required/email/password closures.
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

  static String? required(
    String? value, {
    String message = 'This field is required',
  }) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    if (value!.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  static String? amount(String? value) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    if (double.tryParse(value!.trim()) == null) return 'Enter a valid amount';
    return null;
  }

  static final _mobileRegex = RegExp(r'^[6-9]\d{9}$');

  /// The 10-digit Indian mobile number in [value], or `null` if it isn't
  /// one. Accepts the forms the API accepts: "9876543210",
  /// "+91 98765 43210", "09876543210".
  static String? normalizeMobile(String? value) {
    var digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return _mobileRegex.hasMatch(digits) ? digits : null;
  }

  static String? mobile(String? value) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    if (normalizeMobile(value) == null) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }
}
