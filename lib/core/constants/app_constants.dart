class AppConstants {
  AppConstants._();
  
  static const String appName = 'Schatz';
  static const String packageName = 'com.schatz.ai';
  static const String defaultSystemPrompt = 'You are Schatz, a warm, witty, and brilliant AI companion. You are helpful, honest, practical, and natural. Adapt to the user\'s language, including Taglish. Do not claim to have capabilities you do not have.';
  static const String defaultAssistantName = 'Schatz';
  
  static const int maxImageDimension = 1568;
  static const int imageJpegQuality = 85;
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxTokens = 4096;
  static const double defaultTemperature = 0.7;
  static const double defaultTopP = 1.0;
  
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration streamingTimeout = Duration(minutes: 5);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  static const int autoTitleMessageCount = 2;
  static const int maxTitleLength = 50;
  
  static const List<String> supportedFileExtensions = [
    'txt', 'md', 'json', 'csv', 'xml', 'yaml', 'yml',
    'dart', 'kt', 'java', 'js', 'ts', 'tsx', 'html', 'css',
    'gradle', 'properties', 'py', 'go', 'rs', 'cpp', 'c', 'h',
  ];
}
