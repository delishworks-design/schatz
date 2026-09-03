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
  
  static String getFriendlyMessage(AppError error) {
    return error.message;
  }
}
