import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final Function(String)? onImageSelected;
  final Function(String)? onFileSelected;
  final Function(String)? onVoiceRecorded;
  final bool isGenerating;
  final VoidCallback? onStopGeneration;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onImageSelected,
    this.onFileSelected,
    this.onVoiceRecorded,
    this.isGenerating = false,
    this.onStopGeneration,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _showAttachmentOptions,
              color: AppTheme.textSecondaryColor,
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondaryColor.withOpacity(0.6),
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty && !widget.isGenerating) {
                      widget.onSend(text);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isGenerating)
              IconButton(
                icon: const Icon(Icons.stop_circle),
                onPressed: widget.onStopGeneration,
                color: AppTheme.errorColor,
              )
            else
              IconButton(
                icon: Icon(
                  _hasText ? Icons.send : Icons.mic,
                  color: _hasText
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
                onPressed: _hasText
                    ? () {
                        final text = widget.controller.text.trim();
                        if (text.isNotEmpty) {
                          widget.onSend(text);
                        }
                      }
                    : _startVoiceRecording,
              ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                widget.onImageSelected?.call('');
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                widget.onFileSelected?.call('');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startVoiceRecording() {
    // Handle voice recording
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
}
