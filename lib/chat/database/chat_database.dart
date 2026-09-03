import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

class ChatDatabase {
  static final ChatDatabase _instance = ChatDatabase._();
  factory ChatDatabase() => _instance;
  ChatDatabase._();
  
  List<Conversation> _conversations = [];
  Map<String, List<ChatMessage>> _messages = {};
  bool _initialized = false;
  
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadData();
    _initialized = true;
  }
  
  Future<void> _loadData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final convFile = p.join(dir.path, 'schatz', 'conversations.json');
      final msgFile = p.join(dir.path, 'schatz', 'messages.json');
      
      final convFileObj = await _getFile(convFile);
      final msgFileObj = await _getFile(msgFile);
      
      if (await convFileObj.exists()) {
        final convData = await convFileObj.readAsString();
        final convList = jsonDecode(convData) as List;
        _conversations = convList.map((c) => Conversation.fromJson(c)).toList();
      }
      
      if (await msgFileObj.exists()) {
        final msgData = await msgFileObj.readAsString();
        final msgMap = jsonDecode(msgData) as Map<String, dynamic>;
        _messages = msgMap.map((key, value) {
          return MapEntry(key, (value as List).map((m) => ChatMessage.fromJson(m)).toList());
        });
      }
    } catch (e) {
      debugPrint('Failed to load data: $e');
      _conversations = [];
      _messages = {};
    }
  }
  
  Future<void> _saveData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final schatzDir = p.join(dir.path, 'schatz');
      
      await _createDir(schatzDir);
      
      final convFile = p.join(schatzDir, 'conversations.json');
      final msgFile = p.join(schatzDir, 'messages.json');
      
      // NOTE: Non-atomic dual-file write. If the app crashes between writes,
      // data may become inconsistent. A full atomic write (e.g. write-to-temp
      // then rename) is complex on mobile; best-effort is acceptable here.
      await _getFile(convFile).then((f) => f.writeAsString(
        jsonEncode(_conversations.map((c) => c.toJson()).toList()),
      ));
      
      await _getFile(msgFile).then((f) => f.writeAsString(
        jsonEncode(_messages.map((key, value) {
          return MapEntry(key, value.map((m) => m.toJson()).toList());
        })),
      ));
    } catch (e) {
      debugPrint('Failed to save data: $e');
    }
  }
  
  Future<List<Conversation>> getConversations({bool includeArchived = false}) async {
    var list = List<Conversation>.from(_conversations);
    if (!includeArchived) {
      list = list.where((c) => !c.archived).toList();
    }
    list.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }
  
  Future<Conversation?> getConversation(String id) async {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
  
  Future<Conversation> createConversation({
    String title = 'New Chat',
    String? systemPrompt,
    String? personaId,
    String? providerId,
    String? modelId,
  }) async {
    final conversation = Conversation(
      title: title,
      systemPrompt: systemPrompt,
      personaId: personaId,
      providerId: providerId,
      modelId: modelId,
    );
    _conversations.add(conversation);
    _messages[conversation.id] = [];
    await _saveData();
    return conversation;
  }
  
  Future<void> updateConversation(Conversation conversation) async {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation.copyWith(updatedAt: DateTime.now());
      await _saveData();
    }
  }
  
  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    _messages.remove(id);
    await _saveData();
  }
  
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    return List<ChatMessage>.from(_messages[conversationId] ?? []);
  }
  
  Future<void> addMessage(ChatMessage message) async {
    if (_messages[message.conversationId] == null) {
      _messages[message.conversationId] = [];
    }
    _messages[message.conversationId]!.add(message);
    
    final convIndex = _conversations.indexWhere((c) => c.id == message.conversationId);
    if (convIndex != -1) {
      _conversations[convIndex] = _conversations[convIndex].copyWith(
        updatedAt: DateTime.now(),
        messageCount: _messages[message.conversationId]!.length,
        lastMessagePreview: message.content.length > 100
            ? '${message.content.substring(0, 100)}...'
            : message.content,
      );
    }
    
    try {
      await _saveData();
    } catch (e) {
      debugPrint('Failed to save data: $e');
    }
  }
  
  Future<void> updateMessage(ChatMessage message) async {
    final messages = _messages[message.conversationId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        messages[index] = message;
        await _saveData();
      }
    }
  }
  
  Future<void> deleteMessage(String conversationId, String messageId) async {
    _messages[conversationId]?.removeWhere((m) => m.id == messageId);
    await _saveData();
  }
  
  Future<void> clearMessages(String conversationId) async {
    _messages[conversationId] = [];
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      _conversations[convIndex] = _conversations[convIndex].copyWith(
        messageCount: 0,
        lastMessagePreview: null,
      );
    }
    await _saveData();
  }
  
  Future<List<Conversation>> searchConversations(String query) async {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _conversations.where((c) =>
      c.title.toLowerCase().contains(lowerQuery) ||
      (c.lastMessagePreview?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }
  
  Future<void> clearAll() async {
    _conversations.clear();
    _messages.clear();
    await _saveData();
  }
  
  Future<Map<String, dynamic>> exportData() async {
    return {
      'conversations': _conversations.map((c) => c.toJson()).toList(),
      'messages': _messages.map((key, value) {
        return MapEntry(key, value.map((m) => m.toJson()).toList());
      }),
    };
  }
  
  Future<void> importData(Map<String, dynamic> data) async {
    try {
      if (data['conversations'] != null && data['conversations'] is List) {
        _conversations = (data['conversations'] as List)
            .map((c) => Conversation.fromJson(c))
            .toList();
      }
      if (data['messages'] != null && data['messages'] is Map<String, dynamic>) {
        _messages = (data['messages'] as Map<String, dynamic>).map((key, value) {
          if (value is List) {
            return MapEntry(key, value.map((m) => ChatMessage.fromJson(m)).toList());
          }
          return MapEntry(key, <ChatMessage>[]);
        });
      }
      await _saveData();
    } catch (e) {
      debugPrint('Failed to import data: $e');
    }
  }
  
  Future<void> _createDir(String path) async {
    final dir = io.Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
  
  Future<io.File> _getFile(String path) async {
    return io.File(path);
  }
}
