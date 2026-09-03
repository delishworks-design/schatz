import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../models/plugin.dart';
import '../models/tool.dart';
import '../services/plugin_service.dart';
import '../widgets/tool_card.dart';

class PluginDetailScreen extends StatefulWidget {
  final String pluginId;
  final bool isMarketplace;

  const PluginDetailScreen({
    super.key,
    required this.pluginId,
    this.isMarketplace = false,
  });

  @override
  State<PluginDetailScreen> createState() => _PluginDetailScreenState();
}

class _PluginDetailScreenState extends State<PluginDetailScreen> {
  final PluginService _pluginService = PluginService();
  Plugin? _plugin;
  List<Tool> _tools = [];
  bool _isLoading = true;
  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    _loadPlugin();
  }

  Future<void> _loadPlugin() async {
    final installedPlugins = await _pluginService.getInstalledPlugins();
    _plugin =
        installedPlugins.where((p) => p.id == widget.pluginId).firstOrNull;
    _isInstalled = _plugin != null;

    if (_isInstalled) {
      _tools = _pluginService.getToolsForPlugin(widget.pluginId);
    } else {
      _tools = _getDefaultTools();
    }

    _plugin ??= _getDefaultPlugin();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Plugin _getDefaultPlugin() {
    final plugins = {
      'github': Plugin(
        id: 'github',
        name: 'GitHub',
        description:
            'Interact with GitHub repositories, issues, and pull requests',
        category: PluginCategory.development,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'vercel': Plugin(
        id: 'vercel',
        name: 'Vercel',
        description: 'Deploy and manage Vercel projects and functions',
        category: PluginCategory.deployment,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'supabase': Plugin(
        id: 'supabase',
        name: 'Supabase',
        description: 'Manage Supabase database, auth, and storage',
        category: PluginCategory.database,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'netlify': Plugin(
        id: 'netlify',
        name: 'Netlify',
        description: 'Deploy and manage Netlify sites',
        category: PluginCategory.deployment,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'railway': Plugin(
        id: 'railway',
        name: 'Railway',
        description: 'Deploy and manage Railway projects',
        category: PluginCategory.infrastructure,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'firebase': Plugin(
        id: 'firebase',
        name: 'Firebase',
        description: 'Firebase services integration',
        category: PluginCategory.backend,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'stripe': Plugin(
        id: 'stripe',
        name: 'Stripe',
        description: 'Manage Stripe payments and customers',
        category: PluginCategory.payment,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'cloudflare': Plugin(
        id: 'cloudflare',
        name: 'Cloudflare',
        description: 'Manage Cloudflare Workers and domains',
        category: PluginCategory.infrastructure,
        version: '1.0.0',
        author: 'Schatz',
      ),
      'termux': Plugin(
        id: 'termux',
        name: 'Termux',
        description: 'Execute commands in Termux environment',
        category: PluginCategory.execution,
        version: '1.0.0',
        author: 'Schatz',
      ),
    };
    return plugins[widget.pluginId] ??
        Plugin(
          id: widget.pluginId,
          name: widget.pluginId,
          description: 'Plugin',
          category: PluginCategory.development,
          version: '1.0.0',
          author: 'Schatz',
        );
  }

  List<Tool> _getDefaultTools() {
    final toolsMap = {
      'github': [
        Tool(
            id: 'read',
            name: 'Read Repository',
            description: 'Read repository details, files, or content',
            pluginId: 'github',
            type: ToolType.read),
        Tool(
            id: 'search',
            name: 'Search Code',
            description: 'Search code across repositories',
            pluginId: 'github',
            type: ToolType.search),
        Tool(
            id: 'issue.list',
            name: 'List Issues',
            description: 'List issues in a repository',
            pluginId: 'github',
            type: ToolType.read),
        Tool(
            id: 'issue.create',
            name: 'Create Issue',
            description: 'Create a new issue',
            pluginId: 'github',
            type: ToolType.write),
        Tool(
            id: 'pr.list',
            name: 'List Pull Requests',
            description: 'List pull requests',
            pluginId: 'github',
            type: ToolType.read),
        Tool(
            id: 'pr.create',
            name: 'Create Pull Request',
            description: 'Create a new pull request',
            pluginId: 'github',
            type: ToolType.write),
        Tool(
            id: 'deploy',
            name: 'Trigger Deployment',
            description: 'Trigger GitHub Actions deployment',
            pluginId: 'github',
            type: ToolType.execute),
      ],
      'stripe': [
        Tool(
            id: 'payment.list',
            name: 'List Payments',
            description: 'List recent payments',
            pluginId: 'stripe',
            type: ToolType.read),
        Tool(
            id: 'customer.create',
            name: 'Create Customer',
            description: 'Create a new customer',
            pluginId: 'stripe',
            type: ToolType.write),
        Tool(
            id: 'invoice.create',
            name: 'Create Invoice',
            description: 'Create an invoice',
            pluginId: 'stripe',
            type: ToolType.write),
      ],
      'supabase': [
        Tool(
            id: 'query',
            name: 'Query Database',
            description: 'Execute SQL queries',
            pluginId: 'supabase',
            type: ToolType.read),
        Tool(
            id: 'insert',
            name: 'Insert Data',
            description: 'Insert data into tables',
            pluginId: 'supabase',
            type: ToolType.write),
        Tool(
            id: 'auth.signin',
            name: 'Sign In',
            description: 'Authenticate users',
            pluginId: 'supabase',
            type: ToolType.execute),
      ],
    };
    return toolsMap[widget.pluginId] ?? [];
  }

  Future<void> _installPlugin() async {
    if (_plugin == null) return;

    setState(() => _isLoading = true);

    await _pluginService.savePlugin(_plugin!.copyWith(enabled: true));
    await _pluginService.togglePlugin(_plugin!.id, true);

    if (!mounted) return;
    setState(() {
      _isInstalled = true;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_plugin!.name} installed')),
      );
    }
  }

  Future<void> _uninstallPlugin() async {
    if (_plugin == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall Plugin'),
        content:
            Text('Remove ${_plugin!.name}? This will disable all its tools.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Uninstall',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _pluginService.uninstallPlugin(_plugin!.id);
      if (!mounted) return;
      setState(() => _isInstalled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_plugin!.name} uninstalled')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: _buildContent()),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(_plugin?.name ?? ''),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withOpacity(0.3),
                AppTheme.backgroundColor,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              _getPluginIcon(_plugin?.id ?? ''),
              size: 80,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
          ),
        ),
      ),
      actions: [
        if (_isInstalled)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.pluginSettings,
                  arguments: {'pluginId': _plugin!.id});
            },
          ),
      ],
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildDescription(),
          const SizedBox(height: 24),
          _buildToolsSection(),
          const SizedBox(height: 24),
          _buildPermissions(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _plugin?.name ?? '',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildCategoryChip(
                      _plugin?.category ?? PluginCategory.development),
                  const SizedBox(width: 8),
                  Text('v${_plugin?.version}',
                      style:
                          const TextStyle(color: AppTheme.textSecondaryColor)),
                  const SizedBox(width: 8),
                  Text('by ${_plugin?.author}',
                      style:
                          const TextStyle(color: AppTheme.textSecondaryColor)),
                ],
              ),
            ],
          ),
        ),
        if (_isInstalled)
          ElevatedButton(
            onPressed: _uninstallPlugin,
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Uninstall'),
          )
        else
          ElevatedButton(
            onPressed: _installPlugin,
            child: const Text('Install'),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          _plugin?.description ?? '',
          style:
              const TextStyle(color: AppTheme.textSecondaryColor, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tools',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            Text(
              '${_tools.length} available',
              style: const TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._tools.map((tool) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToolCard(tool: tool, compact: true),
            )),
      ],
    );
  }

  Widget _buildPermissions() {
    if (_plugin?.requiredPermissions.isEmpty ?? true)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Required Permissions',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _plugin!.requiredPermissions.map((permission) {
            return Chip(
              label: Text(permission, style: const TextStyle(fontSize: 12)),
              backgroundColor: AppTheme.surfaceColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(PluginCategory category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.name[0].toUpperCase() + category.name.substring(1),
        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12),
      ),
    );
  }

  IconData _getPluginIcon(String pluginId) {
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
    return icons[pluginId] ?? Icons.extension;
  }
}
