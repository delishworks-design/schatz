import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../core/security/secure_storage.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/models/provider_templates.dart';
import '../../providers/services/provider_service.dart';

class ProviderManagerScreen extends StatefulWidget {
  const ProviderManagerScreen({super.key});

  @override
  State<ProviderManagerScreen> createState() => _ProviderManagerScreenState();
}

class _ProviderManagerScreenState extends State<ProviderManagerScreen> {
  final SecureStorage _storage = SecureStorage();
  List<ProviderProfile> _profiles = [];
  String? _activeProviderId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final storageProfiles = await ProviderService().getProfiles();
    final savedActiveId = await _storage.read('active_provider_id');

    if (!mounted) return;
    if (storageProfiles.isNotEmpty) {
      setState(() {
        _profiles = storageProfiles;
        _activeProviderId = savedActiveId ?? storageProfiles.first.id;
      });
    } else {
      setState(() {
        _profiles = ProviderTemplates.templates;
        if (_profiles.isNotEmpty) {
          _activeProviderId = savedActiveId ?? _profiles.first.id;
        }
      });
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Providers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addProvider,
          ),
        ],
      ),
      body: _profiles.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                final isActive = profile.id == _activeProviderId;
                return _buildProviderCard(profile, isActive);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.api,
            size: 80,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No providers configured',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a provider to start chatting',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addProvider,
            icon: const Icon(Icons.add),
            label: const Text('Add Provider'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(ProviderProfile profile, bool isActive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _toggleActiveProvider(profile),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getProviderIcon(profile.type),
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.selectedModel ?? 'No model selected',
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editProvider(profile),
                tooltip: 'Edit provider',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.errorColor),
                onPressed: () => _deleteProvider(profile),
                tooltip: 'Delete provider',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getProviderIcon(ProviderType type) {
    switch (type) {
      case ProviderType.openai:
        return Icons.smart_toy;
      case ProviderType.gemini:
        return Icons.auto_awesome;
      case ProviderType.groq:
        return Icons.speed;
      case ProviderType.openrouter:
        return Icons.route;
      case ProviderType.mistral:
        return Icons.cloud;
      case ProviderType.cerebras:
        return Icons.memory;
      case ProviderType.custom:
        return Icons.settings_input_component;
    }
  }

  void _addProvider() {
    Navigator.pushNamed(context, AppRouter.providerEditor);
  }

  void _editProvider(ProviderProfile profile) {
    Navigator.pushNamed(context, AppRouter.providerEditor, arguments: {
      'providerId': profile.id,
    });
  }

  void _toggleActiveProvider(ProviderProfile profile) async {
    setState(() {
      _activeProviderId = profile.id;
    });
    await _storage.write('active_provider_id', profile.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${profile.displayName} set as active provider')),
    );
  }

  void _deleteProvider(ProviderProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Provider'),
        content: Text('Delete "${profile.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProviderService().deleteProfile(profile.id);
      if (!mounted) return;
      setState(() {
        _profiles.removeWhere((p) => p.id == profile.id);
        if (_activeProviderId == profile.id) {
          _activeProviderId = _profiles.isNotEmpty ? _profiles.first.id : null;
        }
      });
      if (_activeProviderId != null) {
        await _storage.write('active_provider_id', _activeProviderId!);
      }
    }
  }
}
