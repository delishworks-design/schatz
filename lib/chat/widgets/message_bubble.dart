import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.diamond, size: 18, color: Colors.black),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryColor : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isStreaming)
                    _buildStreamingIndicator()
                  else if (message.hasError)
                    _buildErrorContent()
                  else
                    _buildContent(context, isUser),
                  const SizedBox(height: 4),
                  _buildMetadata(isUser),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStreamingIndicator() {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.content.isEmpty ? 'Thinking...' : message.content,
            style: const TextStyle(color: AppTheme.textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.errorMessage ?? 'An error occurred',
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    if (isUser) {
      return SelectableText(
        message.content,
        style: TextStyle(
          color: isUser ? Colors.black : AppTheme.textColor,
          fontSize: 15,
        ),
      );
    }

    return MarkdownBody(
      data: message.content,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: AppTheme.textColor, fontSize: 15),
        h1: const TextStyle(
            color: AppTheme.textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold),
        h2: const TextStyle(
            color: AppTheme.textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold),
        h3: const TextStyle(
            color: AppTheme.textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600),
        code: const TextStyle(
          backgroundColor: AppTheme.backgroundColor,
          color: AppTheme.primaryColor,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: const TextStyle(color: AppTheme.textSecondaryColor),
        listBullet: const TextStyle(color: AppTheme.textColor),
        a: const TextStyle(color: AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildMetadata(bool isUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            color: (isUser ? Colors.black : AppTheme.textSecondaryColor)
                .withOpacity(0.6),
            fontSize: 10,
          ),
        ),
        if (!isUser) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _copyToClipboard,
            child: Icon(
              Icons.copy,
              size: 12,
              color: AppTheme.textSecondaryColor.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: message.content));
  }
}
