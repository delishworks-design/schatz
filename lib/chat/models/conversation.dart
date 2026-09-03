import 'package:uuid/uuid.dart';

class Conversation {
  final String id;
  final String title;
  final String? systemPrompt;
  final String? personaId;
  final String? providerId;
  final String? modelId;
  final bool pinned;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? lastMessagePreview;

  Conversation({
    String? id,
    this.title = 'New Chat',
    this.systemPrompt,
    this.personaId,
    this.providerId,
    this.modelId,
    this.pinned = false,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.messageCount = 0,
    this.lastMessagePreview,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Conversation copyWith({
    String? title,
    String? systemPrompt,
    String? personaId,
    String? providerId,
    String? modelId,
    bool? pinned,
    bool? archived,
    DateTime? updatedAt,
    int? messageCount,
    String? lastMessagePreview,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      personaId: personaId ?? this.personaId,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      messageCount: messageCount ?? this.messageCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'systemPrompt': systemPrompt,
        'personaId': personaId,
        'providerId': providerId,
        'modelId': modelId,
        'pinned': pinned,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messageCount': messageCount,
        'lastMessagePreview': lastMessagePreview,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'] ?? 'New Chat',
      systemPrompt: json['systemPrompt'],
      personaId: json['personaId'],
      providerId: json['providerId'],
      modelId: json['modelId'],
      pinned: json['pinned'] ?? false,
      archived: json['archived'] ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      messageCount: json['messageCount'] ?? 0,
      lastMessagePreview: json['lastMessagePreview'],
    );
  }
}
