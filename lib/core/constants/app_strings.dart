/// Hardcoded English copy for now. Real localization (English/Gujarati)
/// lives under localizations/ once i18n is wired in; this class is the
/// migration target for the keys defined there.
class AppStrings {
  AppStrings._();

  static const String appName = 'Hari Saurabh Hostel App';

  // Generic
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String submit = 'Submit';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String retry = 'Retry';
  static const String loading = 'Loading...';
  static const String noDataFound = 'No data found';
  static const String somethingWentWrong = 'Something went wrong';
  static const String comingSoon = 'Coming soon';

  // Auth
  static const String login = 'Login';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String createAccount = 'Create Account';
  static const String fullName = 'Full Name';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account?";

  // Validation
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Enter a valid email address';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
}
