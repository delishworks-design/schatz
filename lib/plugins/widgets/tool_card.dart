import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/tool.dart';

class ToolCard extends StatelessWidget {
  final Tool tool;
  final bool compact;
  final bool showParameters;
  final VoidCallback? onTap;

  const ToolCard({
    super.key,
    required this.tool,
    this.compact = false,
    this.showParameters = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard();
    }
    return _buildFullCard();
  }

  Widget _buildCompactCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildTypeIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTypeIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tool.fullName,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tool.requiresAuth)
                    const Icon(Icons.lock, size: 16, color: AppTheme.textSecondaryColor),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tool.description,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  height: 1.5,
                ),
              ),
              if (showParameters && tool.parameters.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildParametersSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    final iconData = _getIconForType(tool.type);
    final color = _getColorForType(tool.type);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  Widget _buildParametersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parameters',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...tool.parameters.entries.map((entry) {
          final param = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  param.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                if (param.required)
                  const Text(' *', style: TextStyle(color: AppTheme.errorColor)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    param.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  IconData _getIconForType(ToolType type) {
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

  Color _getColorForType(ToolType type) {
    switch (type) {
      case ToolType.read:
        return Colors.blue;
      case ToolType.write:
        return Colors.orange;
      case ToolType.execute:
        return Colors.green;
      case ToolType.search:
        return Colors.purple;
      case ToolType.manage:
        return Colors.teal;
    }
  }
}
