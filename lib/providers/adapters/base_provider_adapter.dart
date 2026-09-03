import 'dart:async';
import 'package:dio/dio.dart';
import '../models/provider_profile.dart';

abstract class BaseProviderAdapter {
  Future<List<ProviderModel>> listModels(ProviderProfile profile, {String? apiKeyOverride});
  Stream<String> streamMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
    String? apiKeyOverride,
  });
  Future<String> sendMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
    String? apiKeyOverride,
  });
  Future<ConnectionTestResult> testConnection(ProviderProfile profile, {String? apiKeyOverride});
  void dispose();
}

class ConnectionTestResult {
  final bool success;
  final int latency;
  final String message;
  final String? error;
  final int? modelCount;

  ConnectionTestResult({
    required this.success,
    required this.latency,
    required this.message,
    this.error,
    this.modelCount,
  });
}
