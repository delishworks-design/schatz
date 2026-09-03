import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../models/plugin.dart';
import '../services/plugin_service.dart';

class PluginMarketplaceScreen extends StatefulWidget {
  const PluginMarketplaceScreen({super.key});

  @override
  State<PluginMarketplaceScreen> createState() =>
      _PluginMarketplaceScreenState();
}

class _PluginMarketplaceScreenState extends State<PluginMarketplaceScreen> {
  final PluginService _pluginService = PluginService();
  List<Plugin> _allPlugins = [];
  List<Plugin> _installedPlugins = [];
  List<Plugin> _filteredPlugins = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Development',
    'Deployment',
    'Database',
    'Execution',
    'Payment',
    'Backend',
    'Infrastructure',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    _installedPlugins = await _pluginService.getInstalledPlugins();

    _allPlugins = [
      _buildPluginFromIntegration(
          'github',
          'GitHub',
          'Interact with GitHub repositories, issues, and pull requests',
          PluginCategory.development),
      _buildPluginFromIntegration(
          'vercel',
          'Vercel',
          'Deploy and manage Vercel projects and functions',
          PluginCategory.deployment),
      _buildPluginFromIntegration(
          'supabase',
          'Supabase',
          'Manage Supabase database, auth, and storage',
          PluginCategory.database),
      _buildPluginFromIntegration('netlify', 'Netlify',
          'Deploy and manage Netlify sites', PluginCategory.deployment),
      _buildPluginFromIntegration('railway', 'Railway',
          'Deploy and manage Railway projects', PluginCategory.infrastructure),
      _buildPluginFromIntegration('firebase', 'Firebase',
          'Firebase services integration', PluginCategory.backend),
      _buildPluginFromIntegration('stripe', 'Stripe',
          'Manage Stripe payments and customers', PluginCategory.payment),
      _buildPluginFromIntegration(
          'cloudflare',
          'Cloudflare',
          'Manage Cloudflare Workers and domains',
          PluginCategory.infrastructure),
      _buildPluginFromIntegration('termux', 'Termux',
          'Execute commands in Termux environment', PluginCategory.execution),
    ];

    _filterPlugins();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Plugin _buildPluginFromIntegration(
      String id, String name, String description, PluginCategory category) {
    final isInstalled = _installedPlugins.any((p) => p.id == id);
    return Plugin(
      id: id,
      name: name,
      description: description,
      category: category,
      version: '1.0.0',
      author: 'Schatz',
      enabled: isInstalled,
    );
  }

  void _filterPlugins() {
    _filteredPlugins = _allPlugins.where((plugin) {
      final matchesCategory = _selectedCategory == 'All' ||
          plugin.category.name.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          plugin.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          plugin.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  bool _isInstalled(String pluginId) {
    return _installedPlugins.any((p) => p.id == pluginId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Plugin Marketplace'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildPluginGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _filterPlugins();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search plugins...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                  _filterPlugins();
                });
              },
              backgroundColor: AppTheme.surfaceColor,
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPluginGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredPlugins.length,
      itemBuilder: (context, index) {
        final plugin = _filteredPlugins[index];
        final installed = _isInstalled(plugin.id);
        return _buildMarketplaceCard(plugin, installed);
      },
    );
  }

  Widget _buildMarketplaceCard(Plugin plugin, bool installed) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRouter.pluginDetail,
          arguments: {'pluginId': plugin.id, 'isMarketplace': true},
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPluginIcon(plugin),
                  if (installed)
                    const Icon(Icons.check_circle,
                        color: AppTheme.successColor, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plugin.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  plugin.description,
                  style: const TextStyle(
                      color: AppTheme.textSecondaryColor, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  _buildCategoryChip(plugin.category),
                  const Spacer(),
                  Text(
                    plugin.version,
                    style: const TextStyle(
                        color: AppTheme.textSecondaryColor, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPluginIcon(Plugin plugin) {
    final icons = {
      'github': Icons.code,
      'vercel': Icons.language,
      'supabase': Icons.storage,
      'netlify': Icons.cloud,
      'railway': Icons.train,
      'firebase': Icons.local_fire_department,
      'stripe': Icons.payment,
      'cloudflare': Icons.cloud_outlined,
      'terminal': Icons.terminal,
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icons[plugin.id] ?? Icons.extension,
        color: AppTheme.primaryColor,
        size: 24,
      ),
    );
  }

  Widget _buildCategoryChip(PluginCategory category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.name.substring(0, 1).toUpperCase() +
            category.name.substring(1),
        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10),
      ),
    );
  }
}
