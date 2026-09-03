import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../core/security/secure_storage.dart';
import '../models/conversation.dart';
import '../database/chat_database.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/empty_state.dart';
import '../../providers/services/setup_bootstrap_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChatDatabase _db = ChatDatabase();
  final SetupBootstrapService _bootstrapService = SetupBootstrapService();
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showArchived = false;
  bool _showSetupBanner = false;
  SetupStatus? _setupStatus;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    final storage = SecureStorage();
    final setupSkipped = await storage.read('setup_skipped');
    final result = await _bootstrapService.checkReadiness();

    if (!mounted) return;

    final shouldShowBanner = setupSkipped == 'true' ||
        result.status == SetupStatus.needsApiKey ||
        result.status == SetupStatus.needsModel ||
        result.status == SetupStatus.needsConnectionCheck;

    setState(() {
      _showSetupBanner = shouldShowBanner;
      _setupStatus = result.status;
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    await _db.initialize();
    final conversations =
        await _db.getConversations(includeArchived: _showArchived);
    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
  }

  List<Conversation> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations
        .where((c) =>
            c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (c.lastMessagePreview
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false))
        .toList();
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
          if (_showSetupBanner) _buildSetupBanner(),
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

  Widget _buildSetupBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Setup incomplete',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getSetupBannerMessage(),
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openSetup,
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  String _getSetupBannerMessage() {
    switch (_setupStatus) {
      case SetupStatus.needsApiKey:
        return 'API key not configured';
      case SetupStatus.needsModel:
        return 'No model selected';
      case SetupStatus.needsConnectionCheck:
        return 'Connection check needed';
      default:
        return 'Tap to complete setup';
    }
  }

  void _openSetup() {
    Navigator.pushNamed(context, AppRouter.providerSetup).then((_) {
      _checkSetupStatus();
    });
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
    await _db.updateConversation(
        conversation.copyWith(pinned: !conversation.pinned));
    _loadConversations();
  }

  void _toggleArchive(Conversation conversation) async {
    await _db.updateConversation(
        conversation.copyWith(archived: !conversation.archived));
    _loadConversations();
  }
}
