import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../models/conversation.dart';
import '../database/chat_database.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChatDatabase _db = ChatDatabase();
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    await _db.initialize();
    final conversations = await _db.getConversations(includeArchived: _showArchived);
    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
  }

  List<Conversation> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations.where((c) =>
      c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (c.lastMessagePreview?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Schatz'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.inbox : Icons.archive),
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _loadConversations();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, AppRouter.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
                    ? const EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredConversations.length,
                        itemBuilder: (context, index) {
                          final conversation = _filteredConversations[index];
                          return ConversationTile(
                            conversation: conversation,
                            onTap: () => _openChat(conversation),
                            onDelete: () => _deleteConversation(conversation),
                            onPin: () => _togglePin(conversation),
                            onArchive: () => _toggleArchive(conversation),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.add),
        label: const Text('New Chat'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.black,
      ),
    );
  }

  void _newChat() async {
    final conversation = await _db.createConversation();
    if (mounted) {
      Navigator.pushNamed(context, AppRouter.chat, arguments: {
        'conversationId': conversation.id,
      });
    }
  }

  void _openChat(Conversation conversation) {
    Navigator.pushNamed(context, AppRouter.chat, arguments: {
      'conversationId': conversation.id,
    });
  }

  void _deleteConversation(Conversation conversation) async {
    await _db.deleteConversation(conversation.id);
    _loadConversations();
  }

  void _togglePin(Conversation conversation) async {
    await _db.updateConversation(conversation.copyWith(pinned: !conversation.pinned));
    _loadConversations();
  }

  void _toggleArchive(Conversation conversation) async {
    await _db.updateConversation(conversation.copyWith(archived: !conversation.archived));
    _loadConversations();
  }
}