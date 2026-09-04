import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/provider_profile.dart';
import '../../core/network/network_client.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_handler.dart';
import '../../core/security/secure_storage.dart';
import 'base_provider_adapter.dart';

class GeminiAdapter implements BaseProviderAdapter {
  final NetworkClient _client = NetworkClient();
  final SecureStorage _storage = SecureStorage();

  @override
  Future<List<ProviderModel>> listModels(ProviderProfile profile, {String? apiKeyOverride}) async {
    final apiKey = apiKeyOverride ?? await _storage.read(profile.apiKeyReference);
    if (apiKey == null || apiKey.isEmpty) {
      throw AuthenticationError(message: 'API key not configured.');
    }

    final baseUrl = _normalizeBaseUrl(profile.baseUrl);

    try {
      final response = await _client.get(
        '$baseUrl/models?key=$apiKey',
        headers: {'Content-Type': 'application/json'},
      );

      final data = response.data;
      if (data == null || data['models'] == null) {
        return [];
      }

      return (data['models'] as List).map((model) {
        final name = model['name'] ?? '';
        return ProviderModel(
          id: name,
          name: name.contains('/') ? name.split('/').last : name,
          providerId: profile.id,
          contextLength: _extractContextLength(model),
          supportsVision: _detectVision(name),
          supportsStreaming: _detectStreaming(model),
          supportsToolCalling: _detectToolCalling(name),
          description: model['description'],
        );
      }).toList();
    } on DioException catch (e) {
      throw ErrorHandler.handleGeminiError(e);
    }
  }

  @override
  Stream<String> streamMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
    String? apiKeyOverride,
  }) async* {
    final apiKey = apiKeyOverride ?? await _storage.read(profile.apiKeyReference);
    if (apiKey == null || apiKey.isEmpty) {
      throw AuthenticationError(message: 'API key not configured.');
    }

    if (profile.selectedModel == null || profile.selectedModel!.isEmpty) {
      throw ValidationError(message: 'No model selected for Gemini.');
    }

    final baseUrl = _normalizeBaseUrl(profile.baseUrl);
    final formattedContents = _formatMessages(messages, systemPrompt);

    final requestBody = <String, dynamic>{
      'contents': formattedContents,
      'generationConfig': {
        'temperature': profile.temperature,
        'maxOutputTokens': profile.maxTokens,
        'topP': profile.topP,
      },
    };

    try {
      final response = await _client.dio.post(
        '$baseUrl/models/${profile.selectedModel}:streamGenerateContent?key=$apiKey&alt=sse',
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );

      final stream = response.data.stream;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);

        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.isEmpty) continue;

          try {
            final json = jsonDecode(line);
            final candidate = json['candidates']?[0];
            if (candidate != null) {
              final content = candidate['content'];
              if (content != null) {
                final parts = content['parts'] as List?;
                if (parts != null) {
                  for (final part in parts) {
                    if (part['text'] != null) {
                      yield part['text'] as String;
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Gemini SSE parse error: $e');
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      throw ErrorHandler.handleGeminiError(e);
    }
  }

  @override
  Future<String> sendMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
    String? apiKeyOverride,
  }) async {
    final apiKey = apiKeyOverride ?? await _storage.read(profile.apiKeyReference);
    if (apiKey == null || apiKey.isEmpty) {
      throw AuthenticationError(message: 'API key not configured.');
    }

    if (profile.selectedModel == null || profile.selectedModel!.isEmpty) {
      throw ValidationError(message: 'No model selected for Gemini.');
    }

    final baseUrl = _normalizeBaseUrl(profile.baseUrl);
    final formattedContents = _formatMessages(messages, systemPrompt);

    final requestBody = <String, dynamic>{
      'contents': formattedContents,
      'generationConfig': {
        'temperature': profile.temperature,
        'maxOutputTokens': profile.maxTokens,
        'topP': profile.topP,
      },
    };

    try {
      final response = await _client.post(
        '$baseUrl/models/${profile.selectedModel}:generateContent?key=$apiKey',
        data: requestBody,
        headers: {'Content-Type': 'application/json'},
        cancelToken: cancelToken,
      );

      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return '';
      }

      final content = candidates[0]['content'];
      if (content == null) return '';

      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';

      final buffer = StringBuffer();
      for (final part in parts) {
        if (part['text'] != null) {
          buffer.write(part['text']);
        }
      }
      return buffer.toString();
    } on DioException catch (e) {
      throw ErrorHandler.handleGeminiError(e);
    }
  }

  @override
  Future<ConnectionTestResult> testConnection(ProviderProfile profile, {String? apiKeyOverride}) async {
    final stopwatch = Stopwatch()..start();

    try {
      final models = await listModels(profile, apiKeyOverride: apiKeyOverride);
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
    final contents = <Map<String, dynamic>>[];

    for (final message in messages) {
      final role = message['role'];
      String geminiRole;
      if (role == 'user') {
        geminiRole = 'user';
      } else if (role == 'assistant' || role == 'model') {
        geminiRole = 'model';
      } else {
        geminiRole = 'user';
      }

      final content = message['content'];
      if (content != null && content.isNotEmpty) {
        contents.add({
          'role': geminiRole,
          'parts': [{'text': content}],
        });
      }
    }

    return contents;
  }

  int? _extractContextLength(Map<String, dynamic> model) {
    final inputTokenLimit = model['inputTokenLimit'];
    if (inputTokenLimit != null) {
      return inputTokenLimit as int;
    }
    return null;
  }

  bool _detectVision(String modelId) {
    final visionModels = ['vision', 'gemini-1.5-flash', 'gemini-1.5-pro'];
    return visionModels.any((m) => modelId.toLowerCase().contains(m));
  }

  bool _detectStreaming(Map<String, dynamic> model) {
    final methods = model['methods'] as List?;
    if (methods == null) return true;
    return methods.any((m) => m['name'] == 'streamGenerateContent');
  }

  bool _detectToolCalling(String modelId) {
    final toolModels = ['gemini-1.5-pro'];
    return toolModels.any((m) => modelId.toLowerCase().contains(m));
  }

  String _normalizeBaseUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  @override
  void dispose() {
    _client.dispose();
  }
}
