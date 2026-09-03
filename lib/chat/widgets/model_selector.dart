import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/services/provider_service.dart';

class ModelSelector extends StatefulWidget {
  final String? selectedProviderId;
  final String? selectedModel;
  final ValueChanged<String> onModelChanged;

  const ModelSelector({
    super.key,
    this.selectedProviderId,
    this.selectedModel,
    required this.onModelChanged,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  final ProviderService _providerService = ProviderService();
  List<ProviderProfile> _profiles = [];
  ProviderProfile? _selectedProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final profiles = await _providerService.getProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _selectedProfile = profiles.where((p) => p.id == widget.selectedProviderId).firstOrNull ??
          (profiles.isNotEmpty ? profiles.first : null);
      _isLoading = false;
    });
  }

  void _showModelPicker() {
    if (_selectedProfile == null || _selectedProfile!.availableModels.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Select Model',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _selectedProfile!.displayName,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _selectedProfile!.availableModels.length,
                    itemBuilder: (context, index) {
                      final model = _selectedProfile!.availableModels[index];
                      final isSelected = model.name == widget.selectedModel;

                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                        ),
                        title: Text(model.name),
                        subtitle: Text(
                          _getModelProvider(model.name),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          widget.onModelChanged(model.name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProviderPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Select Provider',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              ...(_profiles.map((profile) => RadioListTile<ProviderProfile>(
                title: Text(profile.displayName),
                subtitle: Text(
                  '${profile.availableModels.length} models',
                  style: const TextStyle(fontSize: 12),
                ),
                value: profile,
                groupValue: _selectedProfile,
                onChanged: (value) {
                  setState(() {
                    _selectedProfile = value;
                  });
                  if (value != null && value.availableModels.isNotEmpty) {
                    widget.onModelChanged(value.availableModels.first.name);
                  }
                  Navigator.pop(context);
                },
              ))),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _getModelProvider(String model) {
    if (model.toLowerCase().contains('gpt')) return 'OpenAI';
    if (model.toLowerCase().contains('claude')) return 'Anthropic';
    if (model.toLowerCase().contains('gemini')) return 'Google';
    if (model.toLowerCase().contains('llama')) return 'Meta';
    return _selectedProfile?.displayName ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 100,
        height: 32,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_selectedProfile == null) {
      return TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Provider'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _showProviderPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getProviderIcon(_selectedProfile!.type.name),
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedProfile!.displayName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.arrow_drop_down, size: 14),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: AppTheme.borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          InkWell(
            onTap: _showModelPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.selectedModel ?? 'Select Model',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const Icon(Icons.arrow_drop_down, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(String type) {
    switch (type.toLowerCase()) {
      case 'openai':
        return Icons.auto_awesome;
      case 'anthropic':
        return Icons.psychology;
      case 'google':
        return Icons.language;
      case 'offline':
        return Icons.offline_bolt;
      default:
        return Icons.cloud;
    }
  }
}
