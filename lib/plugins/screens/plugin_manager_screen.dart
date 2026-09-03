import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../models/plugin.dart';
import '../services/plugin_service.dart';
import '../widgets/plugin_card.dart';

class PluginManagerScreen extends StatefulWidget {
  const PluginManagerScreen({super.key});

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen> {
  final PluginService _pluginService = PluginService();
  List<Plugin> _plugins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    final plugins = await _pluginService.getInstalledPlugins();
    if (!mounted) return;
    setState(() {
      _plugins = plugins;
      _isLoading = false;
    });
  }

  Future<void> _togglePlugin(Plugin plugin, bool enabled) async {
    await _pluginService.togglePlugin(plugin.id, enabled);
    if (!mounted) return;
    setState(() {
      final index = _plugins.indexWhere((p) => p.id == plugin.id);
      if (index != -1) {
        _plugins[index] = _plugins[index].copyWith(enabled: enabled);
      }
    });
  }

  Future<void> _uninstallPlugin(Plugin plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall Plugin'),
        content: Text('Remove ${plugin.name}? This will disable all its tools.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Uninstall', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _pluginService.uninstallPlugin(plugin.id);
      _loadPlugins();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Plugins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () => Navigator.pushNamed(context, AppRouter.pluginMarketplace),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plugins.isEmpty
              ? _buildEmptyState()
              : _buildPluginList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.extension_off, size: 64, color: AppTheme.primaryColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No plugins installed',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse the marketplace to add functionality',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRouter.pluginMarketplace),
            icon: const Icon(Icons.store),
            label: const Text('Open Marketplace'),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plugins.length,
      itemBuilder: (context, index) {
        final plugin = _plugins[index];
        return PluginCard(
          plugin: plugin,
          onToggle: (enabled) => _togglePlugin(plugin, enabled),
          onTap: () => Navigator.pushNamed(
            context,
            AppRouter.pluginDetail,
            arguments: {'pluginId': plugin.id},
          ),
          onSettings: () => Navigator.pushNamed(
            context,
            AppRouter.pluginSettings,
            arguments: {'pluginId': plugin.id},
          ),
          onUninstall: () => _uninstallPlugin(plugin),
        );
      },
    );
  }
}
