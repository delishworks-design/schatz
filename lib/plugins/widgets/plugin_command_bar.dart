import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/tool.dart';
import '../services/plugin_service.dart';
import '../services/tool_executor.dart';

class PluginCommandBar extends StatefulWidget {
  final String? conversationId;
  final Function(Map<String, dynamic>)? onToolExecuted;

  const PluginCommandBar({
    super.key,
    this.conversationId,
    this.onToolExecuted,
  });

  @override
  State<PluginCommandBar> createState() => _PluginCommandBarState();
}

class _PluginCommandBarState extends State<PluginCommandBar> {
  final PluginService _pluginService = PluginService();
  List<Tool> _tools = [];
  List<Tool> _filteredTools = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    final tools = await _pluginService.getEnabledTools();
    setState(() {
      _tools = tools;
      _filteredTools = tools;
    });
  }

  void _filterTools(String query) {
    setState(() {
      _filteredTools = _tools.where((tool) {
        return tool.name.toLowerCase().contains(query.toLowerCase()) ||
            tool.description.toLowerCase().contains(query.toLowerCase()) ||
            tool.fullName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showToolExecutionDialog(Tool tool) {
    final Map<String, TextEditingController> controllers = {};
    for (final param in tool.parameters.entries) {
      controllers[param.key] = TextEditingController();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tool.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tool.description,
                style: const TextStyle(color: AppTheme.textSecondaryColor),
              ),
              if (tool.parameters.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...tool.parameters.entries.map((entry) {
                  final param = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(param.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            if (param.required)
                              const Text(' *',
                                  style: TextStyle(color: AppTheme.errorColor)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          param.description,
                          style: const TextStyle(
                              color: AppTheme.textSecondaryColor, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        if (param.options != null)
                          DropdownButtonFormField<String>(
                            items: param.options!.map((option) {
                              return DropdownMenuItem(
                                  value: option, child: Text(option));
                            }).toList(),
                            onChanged: (value) {
                              controllers[entry.key]?.text = value ?? '';
                            },
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          )
                        else
                          TextField(
                            controller: controllers[entry.key],
                            decoration: InputDecoration(
                              hintText: param.defaultValue?.toString() ?? '',
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (final c in controllers.values) {
                c.dispose();
              }
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final params = <String, dynamic>{};
              for (final entry in controllers.entries) {
                if (entry.value.text.isNotEmpty) {
                  params[entry.key] = entry.value.text;
                }
                entry.value.dispose();
              }
              Navigator.pop(context);
              await _executeTool(tool, params);
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTool(Tool tool, Map<String, dynamic> params) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Executing ${tool.name}...'),
        duration: const Duration(seconds: 1),
      ),
    );

    final executor = ToolExecutorService();
    final result = await executor.execute(tool.fullName, params);

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.content),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Execution failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      widget.onToolExecuted?.call(result.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tools.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isExpanded) _buildExpandedView(),
        _buildCollapsedView(),
      ],
    );
  }

  Widget _buildCollapsedView() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: AppTheme.primaryColor,
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tools.length,
              itemBuilder: (context, index) {
                final tool = _tools[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(_getToolIcon(tool.type), size: 16),
                    label:
                        Text(tool.name, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _showToolExecutionDialog(tool),
                    backgroundColor: AppTheme.surfaceColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Available Tools',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${_tools.length} tools',
                style: const TextStyle(
                    color: AppTheme.textSecondaryColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: _filterTools,
            decoration: InputDecoration(
              hintText: 'Search tools...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _filteredTools.length,
              itemBuilder: (context, index) {
                final tool = _filteredTools[index];
                return ListTile(
                  leading: Icon(_getToolIcon(tool.type), size: 20),
                  title: Text(tool.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    tool.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  dense: true,
                  onTap: () => _showToolExecutionDialog(tool),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getToolIcon(ToolType type) {
    switch (type) {
      case ToolType.read:
        return Icons.visibility;
      case ToolType.write:
        return Icons.edit;
      case ToolType.execute:
        return Icons.play_arrow;
      case ToolType.search:
        return Icons.search;
      case ToolType.manage:
        return Icons.settings;
    }
  }
}
