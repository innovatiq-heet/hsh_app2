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
}
