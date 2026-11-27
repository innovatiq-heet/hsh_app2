/// Thrown by repositories in place of a raw [DioException] — carries the
/// backend's own error message (from the `{status, message}` envelope) so
/// controllers can show it directly instead of a generic failure string.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}
