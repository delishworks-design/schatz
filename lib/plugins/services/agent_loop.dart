import 'dart:async';
import 'package:dio/dio.dart';
import '../../chat/models/chat_message.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/services/provider_service.dart';
import '../models/tool_result.dart';
import '../services/capability_registry.dart';
import '../services/plugin_router.dart';

class AgentLoop {
  static final AgentLoop _instance = AgentLoop._();
  factory AgentLoop() => _instance;
  AgentLoop._();

  final CapabilityRegistry _capabilityRegistry = CapabilityRegistry();
  final PluginRouter _pluginRouter = PluginRouter();
  final ProviderService _providerService = ProviderService();

  bool _isRunning = false;
  bool _isCancelled = false;
  int _iterationCount = 0;
  static const int _maxIterations = 10;

  bool get isRunning => _isRunning;

  void cancel() {
    _isCancelled = true;
  }

  Stream<AgentEvent> run({
    required ProviderProfile provider,
    required List<ChatMessage> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
  }) async* {
    if (_isRunning) return;
    _isRunning = true;
    _isCancelled = false;
    _iterationCount = 0;

    try {
      final allMessages = List<ChatMessage>.from(messages);
      final toolSchemas = _capabilityRegistry.getToolSchemasForProvider(provider.type.name);
      final toolsSection = _capabilityRegistry.buildSystemPromptToolsSection();

      var effectiveSystemPrompt = systemPrompt ?? '';
      if (toolsSection.isNotEmpty) {
        effectiveSystemPrompt = '$effectiveSystemPrompt\n\n$toolsSection';
      }

      String fullResponse = '';

      while (!_isCancelled && _iterationCount < _maxIterations) {
        _iterationCount++;

        final apiMessages = allMessages
            .where((m) => m.status != MessageStatus.error)
            .map((m) => m.toApiFormat())
            .toList();

        yield AgentEvent.thinking();

        ToolCall? detectedToolCall;

        await for (final chunk in _providerService.streamMessage(
          profile: provider,
          messages: apiMessages,
          systemPrompt: effectiveSystemPrompt,
          cancelToken: cancelToken,
        )) {
          if (_isCancelled) break;

          fullResponse += chunk;

          final potentialToolCall = _pluginRouter.parseToolCall(fullResponse);
          if (potentialToolCall != null) {
            detectedToolCall = potentialToolCall;
          }

          yield AgentEvent.streaming(chunk);
        }

        if (_isCancelled) break;

        if (detectedToolCall != null) {
          yield AgentEvent.toolStart(detectedToolCall!);

          final result = await _pluginRouter.route(
            detectedToolCall!.toolFullName,
            detectedToolCall!.arguments,
          );

          yield AgentEvent.toolComplete(detectedToolCall!, result);

          final toolMessage = ChatMessage(
            id: 'tool_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: messages.isNotEmpty ? messages.first.conversationId : '',
            role: MessageRole.tool,
            content: result.content,
            status: result.success ? MessageStatus.sent : MessageStatus.error,
            createdAt: DateTime.now(),
          );
          allMessages.add(toolMessage);

          final assistantMsg = ChatMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: messages.isNotEmpty ? messages.first.conversationId : '',
            role: MessageRole.assistant,
            content: fullResponse,
            status: MessageStatus.sent,
            createdAt: DateTime.now(),
          );
          allMessages.add(assistantMsg);

          continue;
        }

        yield AgentEvent.complete(fullResponse);
        break;
      }

      if (_iterationCount >= _maxIterations && !_isCancelled) {
        yield AgentEvent.complete(fullResponse.isNotEmpty
            ? fullResponse
            : 'I reached the maximum number of tool iterations. Here is what I have so far.');
      }
    } finally {
      _isRunning = false;
    }
  }
}

enum AgentEventType {
  thinking,
  streaming,
  toolStart,
  toolComplete,
  complete,
  error,
}

class AgentEvent {
  final AgentEventType type;
  final String? content;
  final ToolCall? toolCall;
  final ToolResult? toolResult;

  const AgentEvent._({
    required this.type,
    this.content,
    this.toolCall,
    this.toolResult,
  });

  factory AgentEvent.thinking() => const AgentEvent._(type: AgentEventType.thinking);
  factory AgentEvent.streaming(String chunk) => AgentEvent._(type: AgentEventType.streaming, content: chunk);
  factory AgentEvent.toolStart(ToolCall call) => AgentEvent._(type: AgentEventType.toolStart, toolCall: call);
  factory AgentEvent.toolComplete(ToolCall call, ToolResult result) =>
      AgentEvent._(type: AgentEventType.toolComplete, toolCall: call, toolResult: result);
  factory AgentEvent.complete(String response) => AgentEvent._(type: AgentEventType.complete, content: response);
  factory AgentEvent.error(String message) => AgentEvent._(type: AgentEventType.error, content: message);
}

