import 'package:dio/dio.dart';
import 'app_error.dart';

class UnknownError extends AppError {
  UnknownError({
    super.message = 'An unexpected error occurred.',
    super.technicalMessage,
  });
}

class ErrorHandler {
  static AppError handle(dynamic error) {
    if (error is AppError) {
      return error;
    }

    final errorString = error.toString().toLowerCase();

    if (error is Exception) {
      final typeName = error.runtimeType.toString().toLowerCase();
      if (typeName == 'socketexception' || typeName.contains('socket')) {
        return NetworkError(technicalMessage: error.toString());
      }
    }

    if (RegExp(r'\b401\b').hasMatch(errorString) ||
        RegExp(r'\bunauthorized\b').hasMatch(errorString)) {
      return AuthenticationError(technicalMessage: error.toString());
    }

    if (RegExp(r'\b429\b').hasMatch(errorString) ||
        RegExp(r'\brate\s*limit\b').hasMatch(errorString)) {
      return RateLimitError(technicalMessage: error.toString());
    }

    if (RegExp(r'\btimeout\b').hasMatch(errorString)) {
      return TimeoutError(technicalMessage: error.toString());
    }

    if (RegExp(r'\bsocket\b').hasMatch(errorString) ||
        RegExp(r'\bconnection\b').hasMatch(errorString)) {
      return NetworkError(technicalMessage: error.toString());
    }

    if (RegExp(r'\b404\b').hasMatch(errorString) ||
        RegExp(r'\bnot\s*found\b').hasMatch(errorString)) {
      return ModelNotFoundError(technicalMessage: error.toString());
    }

    return UnknownError(
      technicalMessage: error.toString(),
    );
  }

  static AppError handleGeminiError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String? errorMessage;

    if (data is Map) {
      errorMessage = data['error']?['message'];
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutError(technicalMessage: error.message);
      case DioExceptionType.connectionError:
        return NetworkError(technicalMessage: error.message);
      case DioExceptionType.badResponse:
        if (statusCode == 401) {
          return AuthenticationError(
            message: errorMessage ?? 'Invalid API key for Gemini.',
          );
        } else if (statusCode == 429) {
          return RateLimitError(
            message: errorMessage ?? 'Gemini quota exceeded.',
          );
        } else if (statusCode == 403) {
          return AuthenticationError(
            message: errorMessage ?? 'Gemini API key not valid or lacks permissions.',
          );
        }
        return InvalidResponseError(
          message: errorMessage ?? 'Request failed with status $statusCode',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return NetworkError(message: 'Request was cancelled.');
      default:
        return NetworkError(technicalMessage: error.message);
    }
  }

  static String getFriendlyMessage(AppError error) {
    return error.message;
  }
}
