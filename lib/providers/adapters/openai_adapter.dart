import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/provider_profile.dart';
import '../../core/network/network_client.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_handler.dart';
import '../../core/security/secure_storage.dart';

class OpenAIAdapter {
  final NetworkClient _client = NetworkClient();
  final SecureStorage _storage = SecureStorage();
  
  Future<List<ProviderModel>> listModels(ProviderProfile profile) async {
    final apiKey = await _storage.readApiKey(profile.apiKeyReference);
    if (apiKey == null || apiKey.isEmpty) {
      throw AuthenticationError(message: 'API key not configured.');
    }
    
    try {
      final response = await _client.get(
        '${profile.baseUrl}/models',
        headers: {
          'Authorization': 'Bearer $apiKey',
          ...profile.customHeaders,
        },
      );
      
      final data = response.data;
      if (data == null || data['data'] == null) {
        return [];
      }
      
      return (data['data'] as List).map((model) {
        return ProviderModel(
          id: model['id'] ?? '',
          name: model['name'] ?? model['id'] ?? '',
          providerId: profile.id,
          contextLength: model['context_length'],
          supportsVision: _detectVision(model['id'] ?? ''),
          supportsToolCalling: _detectToolCalling(model['id'] ?? ''),
        );
      }).toList();
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
  
  Stream<String> streamMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
  }) async* {
    final apiKey = await _storage.readApiKey(profile.apiKeyReference);
    if (apiKey == null || apiKey.isEmpty) {
      throw AuthenticationError(message: 'API key not configured.');
    }
    
    final formattedMessages = _formatMessages(messages, systemPrompt);
    
    final requestBody = <String, dynamic>{
      'model': profile.selectedModel,
      'messages': formattedMessages,
      'temperature': profile.temperature,
      'max_tokens': profile.maxTokens,
      'top_p': profile.topP,
      'stream': true,
    };

    if (tools != null && tools.isNotEmpty && _detectToolCalling(profile.selectedModel ?? '')) {
      requestBody['tools'] = tools;
    }
    
    try {
      final response = await _client.dio.post(
        '${profile.baseUrl}/chat/completions',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            ...profile.customHeaders,
          },
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
      
      final stream = response.data.stream;
      String buffer = '';
      
      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
          
          final data = trimmed.substring(6);
          if (data == '[DONE]') return;
          
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta'];
            if (delta != null) {
              final content = delta['content'];
              if (content != null) {
                yield content;
              }
              final toolCalls = delta['tool_calls'];
              if (toolCalls != null) {
                for (final tc in toolCalls) {
                  final fn = tc['function'];
                  if (fn != null && fn['arguments'] != null) {
                    yield fn['arguments'] as String;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('SSE parse error: $e');
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      throw ErrorHandler.handle(e);
    }
  }
  
  Future<String> sendMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
  }) async {
    final apiKey = await _storage.readApiKey(profile.apiKeyReference);
    if (apiKey == null || apiKey.isEmpty) {
      throw AuthenticationError(message: 'API key not configured.');
    }
    
    final formattedMessages = _formatMessages(messages, systemPrompt);
    
    final requestBody = <String, dynamic>{
      'model': profile.selectedModel,
      'messages': formattedMessages,
      'temperature': profile.temperature,
      'max_tokens': profile.maxTokens,
      'top_p': profile.topP,
    };

    if (tools != null && tools.isNotEmpty && _detectToolCalling(profile.selectedModel ?? '')) {
      requestBody['tools'] = tools;
    }
    
    try {
      final response = await _client.post(
        '${profile.baseUrl}/chat/completions',
        data: requestBody,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          ...profile.customHeaders,
        },
        cancelToken: cancelToken,
      );
      
      return response.data['choices']?[0]?['message']?['content'] ?? '';
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
  
  Future<ConnectionTestResult> testConnection(ProviderProfile profile) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final models = await listModels(profile);
      stopwatch.stop();
      
      return ConnectionTestResult(
        success: true,
        latency: stopwatch.elapsedMilliseconds,
        modelCount: models.length,
        message: 'Connected successfully',
      );
    } on AuthenticationError catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        latency: stopwatch.elapsedMilliseconds,
        message: 'Authentication failed',
        error: e.message,
      );
    } on RateLimitError catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        latency: stopwatch.elapsedMilliseconds,
        message: 'Rate limit exceeded',
        error: e.message,
      );
    } catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        latency: stopwatch.elapsedMilliseconds,
        message: 'Connection failed',
        error: e.toString(),
      );
    }
  }
  
  List<Map<String, dynamic>> _formatMessages(
    List<Map<String, dynamic>> messages,
    String? systemPrompt,
  ) {
    final formatted = <Map<String, dynamic>>[];
    
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      formatted.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }
    
    for (final message in messages) {
      final role = message['role'];
      if (role == 'tool') {
        formatted.add({
          'role': 'tool',
          'content': message['content'] ?? '',
          'tool_call_id': message['tool_call_id'] ?? '',
        });
      } else {
        formatted.add({
          'role': role,
          'content': message['content'],
        });
      }
    }
    
    return formatted;
  }
  
  bool _detectVision(String modelId) {
    final visionKeywords = ['vision', 'gpt-4o', 'gpt-4-turbo', 'claude-3'];
    return visionKeywords.any((k) => modelId.toLowerCase().contains(k));
  }
  
  bool _detectToolCalling(String modelId) {
    final toolKeywords = ['gpt-4', 'claude-3', 'gemini'];
    return toolKeywords.any((k) => modelId.toLowerCase().contains(k));
  }
  
  void dispose() {
    _client.dispose();
  }
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
