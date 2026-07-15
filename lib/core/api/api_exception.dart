class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isRetryable = false});

  final String message;
  final int? statusCode;
  final bool isRetryable;

  @override
  String toString() => 'ApiException(status: $statusCode, retryable: $isRetryable, message: $message)';
}
