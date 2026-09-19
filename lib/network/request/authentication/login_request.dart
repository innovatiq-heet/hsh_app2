class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});
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
}
