import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system, tool }

enum MessageStatus { sending, sent, error, streaming }

class ChatMessage {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? modelId;
  final String? providerId;
  final Map<String, dynamic>? metadata;
  final List<String> attachmentIds;
  final String? errorMessage;
  final int? inputTokens;
  final int? outputTokens;
  final String? toolCallId;
  
  ChatMessage({
    String? id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.status = MessageStatus.sent,
    DateTime? createdAt,
    this.updatedAt,
    this.modelId,
    this.providerId,
    this.metadata,
    this.attachmentIds = const [],
    this.errorMessage,
    this.inputTokens,
    this.outputTokens,
    this.toolCallId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
  
  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;
  bool get isTool => role == MessageRole.tool;
  bool get isStreaming => status == MessageStatus.streaming;
  bool get hasError => status == MessageStatus.error;
  bool get hasAttachments => attachmentIds.isNotEmpty;
  
  int get estimatedTokens {
    final words = content.split(RegExp(r'\s+'));
    return (words.length * 1.33).ceil();
  }
  
  ChatMessage copyWith({
    String? content,
    MessageStatus? status,
    DateTime? updatedAt,
    String? errorMessage,
    int? inputTokens,
    int? outputTokens,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      modelId: modelId,
      providerId: providerId,
      metadata: metadata,
      attachmentIds: attachmentIds,
      errorMessage: errorMessage ?? this.errorMessage,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      toolCallId: toolCallId,
    );
  }
  
  Map<String, dynamic> toApiFormat() {
    if (role == MessageRole.tool) {
      return {
        'role': 'tool',
        'content': content,
        'tool_call_id': toolCallId ?? '',
      };
    }
    return {
      'role': role.name,
      'content': content,
    };
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'role': role.name,
    'content': content,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'modelId': modelId,
    'providerId': providerId,
    'metadata': metadata,
    'attachmentIds': attachmentIds,
    'errorMessage': errorMessage,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'toolCallId': toolCallId,
  };
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      conversationId: json['conversationId'],
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.assistant,
      ),
      content: json['content'] ?? '',
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      modelId: json['modelId'],
      providerId: json['providerId'],
      metadata: json['metadata'],
      attachmentIds: List<String>.from(json['attachmentIds'] ?? []),
      errorMessage: json['errorMessage'],
      inputTokens: json['inputTokens'],
      outputTokens: json['outputTokens'],
      toolCallId: json['toolCallId'],
    );
  }
}
