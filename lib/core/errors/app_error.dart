abstract class AppError implements Exception {
  final String message;
  final String? technicalMessage;
  final int? statusCode;

  AppError({
    required this.message,
    this.technicalMessage,
    this.statusCode,
  });

  @override
  String toString() =>
      technicalMessage != null ? '$message ($technicalMessage)' : message;
}

class AuthenticationError extends AppError {
  AuthenticationError({
    super.message = 'Authentication failed. Please check your API key.',
    super.technicalMessage,
    super.statusCode = 401,
  });
}

class RateLimitError extends AppError {
  final Duration? retryAfter;

  RateLimitError({
    super.message = 'Rate limit exceeded. Please try again later.',
    super.technicalMessage,
    super.statusCode = 429,
    this.retryAfter,
  });
}

class NetworkError extends AppError {
  NetworkError({
    super.message = 'Network error. Please check your connection.',
    super.technicalMessage,
  });
}

class TimeoutError extends AppError {
  TimeoutError({
    super.message = 'Request timed out. Please try again.',
    super.technicalMessage,
  });
}

class ModelNotFoundError extends AppError {
  ModelNotFoundError({
    super.message = 'Model not found. Please select a different model.',
    super.technicalMessage,
    super.statusCode = 404,
  });
}

class UnsupportedCapabilityError extends AppError {
  UnsupportedCapabilityError({
    super.message = 'This model does not support this feature.',
    super.technicalMessage,
  });
}

class ProviderUnavailableError extends AppError {
  ProviderUnavailableError({
    super.message = 'Provider is currently unavailable.',
    super.technicalMessage,
  });
}

class InvalidResponseError extends AppError {
  InvalidResponseError({
    super.message = 'Invalid response from provider.',
    super.technicalMessage,
    super.statusCode,
  });
}

class StorageError extends AppError {
  StorageError({
    super.message = 'Storage error occurred.',
    super.technicalMessage,
  });
}

class PermissionError extends AppError {
  PermissionError({
    super.message = 'Permission denied.',
    super.technicalMessage,
  });
}

class ValidationError extends AppError {
  ValidationError({
    super.message = 'Validation failed.',
    super.technicalMessage,
  });
}
