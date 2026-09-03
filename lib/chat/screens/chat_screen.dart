import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/errors/app_error.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/services/provider_service.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../database/chat_database.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_composer.dart';
import '../widgets/activity_trace.dart';
import '../widgets/model_selector.dart';
import '../../plugins/widgets/plugin_command_bar.dart';
import '../../plugins/services/agent_loop.dart';
import '../../plugins/services/capability_registry.dart';
import '../../plugins/services/plugin_router.dart';
import '../services/title_generator.dart';
import '../services/context_manager.dart';
import '../models/activity_step.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final String? conversationId;

  const ChatScreen({super.key, this.initialPrompt, this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ChatDatabase _db = ChatDatabase();
  final ProviderService _providerService = ProviderService();
  final ContextManager _contextManager = ContextManager();
  final CapabilityRegistry _capabilityRegistry = CapabilityRegistry();
  final PluginRouter _pluginRouter = PluginRouter();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  Conversation? _conversation;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isCancelled = false;
  String _currentStreamingContent = '';
  CancelToken? _cancelToken;
  ProviderProfile? _activeProvider;
  List<ActivityStep> _activitySteps = [];
  bool _showActivityTrace = false;
  int _tokenCount = 0;
  DateTime? _generationStartTime;
  final AgentLoop _agentLoop = AgentLoop();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final conversationId = args?['conversationId'] as String?;
    final initialPrompt =
        widget.initialPrompt ?? args?['initialPrompt'] as String?;

    await _db.initialize();

    final profiles = await _providerService.getProfiles();
    if (profiles.isNotEmpty) {
      _activeProvider = profiles.first;
    }

    if (conversationId != null) {
      _conversation = await _db.getConversation(conversationId);
      _messages = await _db.getMessages(conversationId);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _scrollToBottom();

    if (initialPrompt != null && initialPrompt.isNotEmpty) {
      _textController.text = initialPrompt;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _sendMessage(initialPrompt);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _conversation?.title ?? 'New Chat',
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            ModelSelector(
              selectedProviderId: _activeProvider?.id,
              selectedModel: _activeProvider?.selectedModel,
              onModelChanged: _handleModelChanged,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle),
            onPressed: _isGenerating ? () => _stopGeneration() : null,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(
                  value: 'clear', child: Text('Clear Messages')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && _currentStreamingContent.isEmpty
                    ? _buildEmptyChat()
                    : _buildMessageList(),
          ),
          if (_showActivityTrace && _activitySteps.isNotEmpty)
            ActivityTrace(
              steps: _activitySteps,
              isExpanded: _showActivityTrace,
              tokenCount: _tokenCount,
              elapsed: _generationStartTime != null
                  ? DateTime.now().difference(_generationStartTime!)
                  : null,
            ),
          PluginCommandBar(
            conversationId: _conversation?.id,
            onToolExecuted: _handleToolExecution,
          ),
          ChatComposer(
            controller: _textController,
            onSend: _sendMessage,
            onImageSelected: _handleImageSelection,
            onFileSelected: _handleFileSelection,
            onVoiceRecorded: _handleVoiceRecording,
            isGenerating: _isGenerating,
            onStopGeneration: _stopGeneration,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.diamond,
            size: 80,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Walang laman pa... let\'s chat!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount:
          _messages.length + (_currentStreamingContent.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return MessageBubble(
            message: ChatMessage(
              conversationId: _conversation?.id ?? '',
              role: MessageRole.assistant,
              content: _currentStreamingContent,
              status: MessageStatus.streaming,
            ),
          );
        }
        return MessageBubble(message: _messages[index]);
      },
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    if (_conversation == null) {
      _conversation = await _db.createConversation();
    }

    final userMessage = ChatMessage(
      conversationId: _conversation!.id,
      role: MessageRole.user,
      content: text.trim(),
    );

    try {
      await _db.addMessage(userMessage);
    } catch (e) {
      debugPrint('Failed to save message: $e');
    }

    setState(() {
      _messages.add(userMessage);
      _currentStreamingContent = '';
    });
    _scrollToBottom();
    _textController.clear();

    if (_messages.length == 1) {
      _generateTitle(text);
    }

    await _generateResponse();
  }

  Future<void> _generateResponse() async {
    setState(() {
      _isGenerating = true;
      _isCancelled = false;
      _currentStreamingContent = '';
      _tokenCount = 0;
      _generationStartTime = DateTime.now();
      _activitySteps = [
        ActivityStep(
            name: 'Connecting to provider...',
            status: ActivityStepStatus.inProgress),
        ActivityStep(name: 'Sending messages...'),
        ActivityStep(name: 'Receiving response...'),
        ActivityStep(name: 'Processing tokens...'),
      ];
      _showActivityTrace = true;
    });

    _cancelToken = CancelToken();

    if (_activeProvider == null) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _showActivityTrace = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No active provider selected. Please configure a provider.')),
        );
      }
      return;
    }

    try {
      _addActivityStep(0, ActivityStepStatus.completed);
      _addActivityStep(1, ActivityStepStatus.inProgress);

      await for (final event in _agentLoop.run(
        provider: _activeProvider!,
        messages: _messages,
        systemPrompt: _conversation?.systemPrompt,
        cancelToken: _cancelToken,
      )) {
        if (_isCancelled) break;

        switch (event.type) {
          case AgentEventType.thinking:
            break;
          case AgentEventType.streaming:
            if (mounted) {
              setState(() {
                _currentStreamingContent += event.content ?? '';
                _tokenCount = (_currentStreamingContent.length / 4).ceil();
              });
              _scrollToBottom();
            }
            break;
          case AgentEventType.toolStart:
            _addActivityStep(1, ActivityStepStatus.completed);
            _addActivityStep(2, ActivityStepStatus.inProgress);
            if (mounted) {
              setState(() {
                _currentStreamingContent =
                    'Using tool: ${event.toolCall?.toolFullName}...';
              });
            }
            break;
          case AgentEventType.toolComplete:
            if (event.toolResult != null && mounted) {
              final toolMessage = ChatMessage(
                conversationId: _conversation?.id ?? '',
                role: MessageRole.tool,
                content: event.toolResult!.content,
                status: event.toolResult!.success
                    ? MessageStatus.sent
                    : MessageStatus.error,
                toolCallId: event.toolCall?.toolFullName,
              );
              setState(() {
                _messages.add(toolMessage);
                _currentStreamingContent = '';
              });
              _db.addMessage(toolMessage);
            }
            break;
          case AgentEventType.complete:
            _addActivityStep(2, ActivityStepStatus.completed);
            _addActivityStep(3, ActivityStepStatus.inProgress);

            final responseContent = event.content ?? '';
            if (responseContent.trim().isNotEmpty) {
              final assistantMessage = ChatMessage(
                conversationId: _conversation?.id ?? '',
                role: MessageRole.assistant,
                content: responseContent,
                modelId: _activeProvider?.selectedModel,
                providerId: _activeProvider?.id,
              );

              await _db.addMessage(assistantMessage);

              _addActivityStep(3, ActivityStepStatus.completed);

              if (mounted) {
                setState(() {
                  _messages.add(assistantMessage);
                  _currentStreamingContent = '';
                  _isGenerating = false;
                });
              }
            } else {
              if (mounted) {
                setState(() {
                  _currentStreamingContent = '';
                  _isGenerating = false;
                });
              }
            }
            break;
          case AgentEventType.error:
            _handleError(event.content ?? 'Unknown error');
            break;
        }
      }

      _autoCollapseTrace();
    } on AuthenticationError catch (e) {
      _handleError(e.message);
    } on RateLimitError catch (e) {
      _handleError(e.message);
    } on TimeoutError catch (e) {
      _handleError(e.message);
    } on NetworkError catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('An unexpected error occurred');
    }
  }

  void _addActivityStep(int index, ActivityStepStatus status) {
    if (index < _activitySteps.length) {
      setState(() {
        _activitySteps[index] = _activitySteps[index].copyWith(
          status: status,
          duration: _generationStartTime != null
              ? DateTime.now().difference(_generationStartTime!)
              : null,
        );
      });
    }
  }

  void _autoCollapseTrace() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isGenerating) {
        setState(() => _showActivityTrace = false);
      }
    });
  }

  void _handleError(String message) {
    final errorMessage = ChatMessage(
      conversationId: _conversation?.id ?? '',
      role: MessageRole.assistant,
      content: 'Error: $message',
      status: MessageStatus.error,
      errorMessage: message,
    );

    if (mounted) {
      setState(() {
        _messages.add(errorMessage);
        _isGenerating = false;
        _currentStreamingContent = '';
      });
    }
  }

  void _stopGeneration() {
    _isCancelled = true;
    _cancelToken?.cancel('User cancelled');

    if (_currentStreamingContent.isNotEmpty && _conversation != null) {
      final partialResponse = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: _conversation!.id,
        role: MessageRole.assistant,
        content: _currentStreamingContent,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(partialResponse);
        _isGenerating = false;
        _currentStreamingContent = '';
      });
      _db.addMessage(partialResponse);
    } else {
      setState(() {
        _isGenerating = false;
        _currentStreamingContent = '';
      });
    }
  }

  Future<void> _generateTitle(String firstMessage) async {
    try {
      final title = await TitleGenerator.generate(firstMessage);
      if (title != null && _conversation != null) {
        await _db.updateConversation(_conversation!.copyWith(title: title));
        if (mounted) {
          setState(() => _conversation = _conversation!.copyWith(title: title));
        }
      }
    } catch (e) {
      debugPrint('Failed to generate title: $e');
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'rename':
        _showRenameDialog();
        break;
      case 'clear':
        _clearMessages();
        break;
      case 'delete':
        _deleteChat();
        break;
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _conversation?.title);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new title'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_conversation != null) {
                await _db.updateConversation(
                  _conversation!.copyWith(title: controller.text),
                );
                setState(() => _conversation =
                    _conversation!.copyWith(title: controller.text));
              }
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _clearMessages() async {
    if (_conversation != null) {
      await _db.clearMessages(_conversation!.id);
      setState(() {
        _messages = [];
        _conversation = _conversation!.copyWith(
          messageCount: 0,
          lastMessagePreview: null,
        );
      });
    }
  }

  void _deleteChat() async {
    if (_conversation != null) {
      await _db.deleteConversation(_conversation!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  void _handleImageSelection(String imagePath) {
    // Handle image selection
  }

  void _handleFileSelection(String filePath) {
    // Handle file selection
  }

  void _handleVoiceRecording(String audioPath) {
    // Handle voice recording
  }

  void _handleModelChanged(String model) {
    final oldProviderId = _activeProvider?.id;
    final provider = _providerService.findProviderForModel(model);
    if (provider != null) {
      final newProvider = provider.copyWith(selectedModel: model);
      setState(() => _activeProvider = newProvider);

      if (oldProviderId != provider.id && _conversation != null) {
        _contextManager.onModelSwitch(
          conversationId: _conversation!.id,
          oldProviderId: oldProviderId,
          newProviderId: provider.id,
          messages: _messages,
        );
      }
    }
  }

  void _handleToolExecution(Map<String, dynamic> result) {
    // Handle tool execution result - could add to activity trace or display
    debugPrint('Tool executed: $result');
  }
}
