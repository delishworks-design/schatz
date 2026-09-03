import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/plugin.dart';

class PluginCard extends StatelessWidget {
  final Plugin plugin;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onSettings;
  final VoidCallback? onUninstall;

  const PluginCard({
    super.key,
    required this.plugin,
    this.onToggle,
    this.onTap,
    this.onSettings,
    this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plugin.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _buildCategoryChip(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plugin.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'v${plugin.version}',
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        if (onSettings != null)
                          IconButton(
                            icon: const Icon(Icons.settings, size: 20),
                            onPressed: onSettings,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onToggle != null)
                Switch(
                  value: plugin.enabled,
                  onChanged: onToggle,
                  thumbColor: WidgetStateProperty.all(AppTheme.primaryColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final icons = {
      'github': Icons.code,
      'vercel': Icons.language,
      'supabase': Icons.storage,
      'netlify': Icons.cloud,
      'railway': Icons.train,
      'firebase': Icons.local_fire_department,
      'stripe': Icons.payment,
      'cloudflare': Icons.cloud_outlined,
      'termux': Icons.terminal,
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icons[plugin.id] ?? Icons.extension,
        color: AppTheme.primaryColor,
        size: 24,
      ),
    );
  }

  Widget _buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        plugin.category.name[0].toUpperCase() +
            plugin.category.name.substring(1),
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
