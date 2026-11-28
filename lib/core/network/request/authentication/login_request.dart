class LoginRequest {
  final String studentId;
  final String? email;
  final String? password;

  /// A warden-issued 6-digit code, required from a student's/leader's second
  /// login onward or when transferring to a new device / reinstalled app.
  final String? code;

  /// Per-install cryptographic UUID + phone hardware details so the backend
  /// binds and verifies the student's login instance.
  final Map<String, dynamic>? deviceInfo;

  const LoginRequest({
    String? studentId,
    String? email,
    this.password,
    this.code,
    this.deviceInfo,
  })  : studentId = studentId ?? email ?? '',
        email = email ?? studentId;

  Map<String, dynamic> toJson() => {
        'username': studentId,
        'bank_code': studentId,
        'student_id': studentId,
        'email': email ?? studentId,
        'password': password ?? '',
        // Lets the backend scope the second-login code gate (§5.7b) to this
        // app only — the attendance web portal must keep working ungated.
        'client': 'hsh_app2_mobile',
        if (code != null && code!.trim().isNotEmpty) 'code': code!.trim(),
        ...?deviceInfo,
      };
}

class RegisterRequest {
  final String name;
  final String email;
  final String password;

  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'password': password,
      };
}
