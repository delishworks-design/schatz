import '../models/chat_message.dart';
import '../../core/security/secure_storage.dart';

class ContextManager {
  static final ContextManager _instance = ContextManager._();
  factory ContextManager() => _instance;
  ContextManager._();

  final SecureStorage _storage = SecureStorage();
  
  String? _currentProviderId;
  String? _currentModelId;
  List<ChatMessage> _contextBuffer = [];
  int _maxContextTokens = 4000;
  int _contextWindowTokens = 8000;

  String? get currentProviderId => _currentProviderId;
  String? get currentModelId => _currentModelId;
  List<ChatMessage> get contextBuffer => List.unmodifiable(_contextBuffer);

  Future<void> initialize() async {
    _currentProviderId = await _storage.read('active_provider_id');
    _currentModelId = await _storage.read('active_model_id');
    _maxContextTokens = int.tryParse(await _storage.read('max_context_tokens') ?? '4000') ?? 4000;
    _contextWindowTokens = int.tryParse(await _storage.read('context_window_tokens') ?? '8000') ?? 8000;
  }

  Future<void> setCurrentProvider(String providerId) async {
    _currentProviderId = providerId;
    await _storage.write('active_provider_id', providerId);
  }

  Future<void> setCurrentModel(String modelId, {String? conversationId}) async {
    final previousModel = _currentModelId;
    _currentModelId = modelId;
    await _storage.write('active_model_id', modelId);

    if (previousModel != null && previousModel != modelId) {
      await _onModelChanged(previousModel, modelId, conversationId: conversationId);
    }
  }

  Future<void> onModelSwitch({
    required String conversationId,
    String? oldProviderId,
    String? newProviderId,
    List<ChatMessage>? messages,
  }) async {
    if (oldProviderId != null && newProviderId != null && oldProviderId != newProviderId) {
      if (messages != null && messages.isNotEmpty) {
        updateContextBuffer(messages);
        final summary = _generateContextSummary();
        _contextBuffer = [
          ChatMessage(
            conversationId: conversationId,
            role: MessageRole.system,
            content: 'Context summary from previous provider:\n$summary',
          ),
        ];
      }
    }
  }

  Future<void> _onModelChanged(String oldModel, String newModel, {String? conversationId}) async {
    if (_contextBuffer.isNotEmpty) {
      final summary = _generateContextSummary();
      _contextBuffer = [
        ChatMessage(
          conversationId: conversationId ?? '',
          role: MessageRole.system,
          content: 'Context summary from previous model ($oldModel):\n$summary',
        ),
      ];
    }
  }

  String _generateContextSummary() {
    if (_contextBuffer.isEmpty) return 'No previous context.';

    final topics = <String>{};
    for (final message in _contextBuffer) {
      if (message.role == MessageRole.user) {
        final words = message.content.toLowerCase().split(' ');
        for (final word in words) {
          if (word.length > 4) {
            topics.add(word);
          }
        }
      }
    }

    final recentMessages = _contextBuffer.length > 5
        ? _contextBuffer.sublist(_contextBuffer.length - 5)
        : _contextBuffer;

    final summary = StringBuffer();
    summary.writeln('Previous conversation included ${_contextBuffer.length} messages.');
    if (topics.isNotEmpty) {
      summary.writeln('Topics discussed: ${topics.take(5).join(", ")}.');
    }
    summary.writeln('\nRecent messages:');
    for (final msg in recentMessages) {
      summary.writeln('${msg.role.name}: ${msg.content.substring(0, msg.content.length.clamp(0, 100))}');
    }

    return summary.toString();
  }

  List<ChatMessage> buildContext({
    required List<ChatMessage> messages,
    String? systemPrompt,
    int? maxTokens,
  }) {
    final result = <ChatMessage>[];
    int tokenCount = 0;
    final limit = maxTokens ?? _maxContextTokens;

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      result.add(ChatMessage(
        conversationId: '',
        role: MessageRole.system,
        content: systemPrompt,
      ));
      tokenCount += _estimateTokens(systemPrompt);
    }

    if (_contextBuffer.isNotEmpty) {
      for (final msg in _contextBuffer) {
        if (msg.role == MessageRole.tool) {
          result.add(msg);
          continue;
        }
        final msgTokens = _estimateTokens(msg.content);
        if (tokenCount + msgTokens > limit) break;
        result.add(msg);
        tokenCount += msgTokens;
      }
    }

    final recentMessages = List<ChatMessage>.from(messages).reversed.toList();
    final messagesToAdd = <ChatMessage>[];

    for (final msg in recentMessages) {
      if (msg.role == MessageRole.tool) {
        messagesToAdd.insert(0, msg);
        continue;
      }
      final msgTokens = _estimateTokens(msg.content);
      if (tokenCount + msgTokens > limit) break;
      messagesToAdd.insert(0, msg);
      tokenCount += msgTokens;
    }

    result.addAll(messagesToAdd);

    return result;
  }

  void updateContextBuffer(List<ChatMessage> messages) {
    _contextBuffer = List.from(messages);
    _trimContextBuffer();
  }

  void addToContextBuffer(ChatMessage message) {
    _contextBuffer.add(message);
    _trimContextBuffer();
  }

  void _trimContextBuffer() {
    int tokenCount = 0;
    final trimmed = <ChatMessage>[];

    for (int i = _contextBuffer.length - 1; i >= 0; i--) {
      final msg = _contextBuffer[i];
      final msgTokens = _estimateTokens(msg.content);
      if (tokenCount + msgTokens > _contextWindowTokens) break;
      trimmed.insert(0, msg);
      tokenCount += msgTokens;
    }

    _contextBuffer = trimmed;
  }

  int _estimateTokens(String text) {
    return (text.length / 4).ceil();
  }

  int get currentTokenCount {
    int count = 0;
    for (final msg in _contextBuffer) {
      count += _estimateTokens(msg.content);
    }
    return count;
  }

  double get contextUtilization {
    if (_maxContextTokens == 0) return 0;
    return currentTokenCount / _maxContextTokens;
  }

  Future<void> setMaxContextTokens(int tokens) async {
    _maxContextTokens = tokens;
    await _storage.write('max_context_tokens', tokens.toString());
    _trimContextBuffer();
  }

  void clearContext() {
    _contextBuffer.clear();
  }

  Map<String, dynamic> getContextInfo() {
    return {
      'providerId': _currentProviderId,
      'modelId': _currentModelId,
      'bufferSize': _contextBuffer.length,
      'tokenCount': currentTokenCount,
      'maxTokens': _maxContextTokens,
      'utilization': contextUtilization,
      'windowTokens': _contextWindowTokens,
    };
  }

  Future<Map<String, dynamic>> exportContext() async {
    return {
      'providerId': _currentProviderId,
      'modelId': _currentModelId,
      'contextBuffer': _contextBuffer.map((m) => m.toApiFormat()).toList(),
      'maxTokens': _maxContextTokens,
      'windowTokens': _contextWindowTokens,
    };
  }

  Future<void> importContext(Map<String, dynamic> data) async {
    if (data['providerId'] != null) {
      _currentProviderId = data['providerId'];
    }
    if (data['modelId'] != null) {
      _currentModelId = data['modelId'];
    }
    if (data['maxTokens'] != null) {
      _maxContextTokens = data['maxTokens'];
    }
    if (data['windowTokens'] != null) {
      _contextWindowTokens = data['windowTokens'];
    }
  }
}
