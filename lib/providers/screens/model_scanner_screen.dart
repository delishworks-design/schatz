import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/services/provider_service.dart';

class ModelScannerScreen extends StatefulWidget {
  final String? providerId;

  const ModelScannerScreen({super.key, this.providerId});

  @override
  State<ModelScannerScreen> createState() => _ModelScannerScreenState();
}

class _ModelScannerScreenState extends State<ModelScannerScreen> {
  final ProviderService _providerService = ProviderService();
  List<ProviderModel> _models = [];
  bool _isScanning = false;
  String? _error;
  ProviderProfile? _selectedProvider;
  List<ProviderProfile> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final profiles = await _providerService.getProfiles();
    if (!mounted) return;
    setState(() {
      _providers = profiles;
      if (profiles.isNotEmpty) {
        _selectedProvider = profiles.first;
      }
    });

    if (widget.providerId != null) {
      try {
        _selectedProvider = profiles.firstWhere(
          (p) => p.id == widget.providerId,
          orElse: () => profiles.isNotEmpty ? profiles.first : null!,
        );
      } catch (_) {}
    }
  }

  Future<void> _scanModels() async {
    if (_selectedProvider == null) {
      setState(() => _error = 'Please select a provider first');
      return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
      _models = [];
    });

    try {
      final models = await _providerService.listModels(_selectedProvider!);
      if (!mounted) return;
      setState(() {
        _models = models;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to scan models: $e';
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Model Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanModels,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProviderSelector(),
          _buildScanButton(),
          Expanded(
            child: _buildModelList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedProvider?.id,
        decoration: const InputDecoration(
          labelText: 'Select Provider',
          border: OutlineInputBorder(),
        ),
        items: _providers.map((provider) {
          return DropdownMenuItem(
            value: provider.id,
            child: Text(provider.displayName),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedProvider = _providers.firstWhere((p) => p.id == value);
            });
          }
        },
      ),
    );
  }

  Widget _buildScanButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isScanning ? null : _scanModels,
          icon: _isScanning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.radar),
          label: Text(_isScanning ? 'Scanning...' : 'Scan Models'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildModelList() {
    if (_isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for available models...',
                style: TextStyle(color: AppTheme.textSecondaryColor)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _scanModels,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_models.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 48, color: AppTheme.textSecondaryColor),
            SizedBox(height: 16),
            Text('No models found',
                style: TextStyle(color: AppTheme.textSecondaryColor)),
            SizedBox(height: 8),
            Text('Tap "Scan Models" to discover available models',
                style: TextStyle(
                    color: AppTheme.textSecondaryColor, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _models.length,
      itemBuilder: (context, index) {
        final model = _models[index];
        return _buildModelCard(model);
      },
    );
  }

  Widget _buildModelCard(ProviderModel model) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.smart_toy, color: AppTheme.primaryColor),
        ),
        title: Text(model.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: _buildModelSubtitle(model),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showModelDetails(model),
        ),
      ),
    );
  }

  Widget _buildModelSubtitle(ProviderModel model) {
    final features = <String>[];
    if (model.supportsVision) features.add('Vision');
    if (model.supportsStreaming) features.add('Streaming');
    if (model.supportsToolCalling) features.add('Tools');
    if (model.contextLength != null)
      features.add('${(model.contextLength! / 1000).toStringAsFixed(1)}K');

    return Text(
      features.isEmpty ? 'No features detected' : features.join(' • '),
      style: const TextStyle(fontSize: 12),
    );
  }

  void _showModelDetails(ProviderModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('ID', model.id),
            if (model.contextLength != null)
              _buildDetailRow(
                  'Context Length', '${model.contextLength} tokens'),
            const Divider(),
            const Text('Capabilities:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildCapabilityChip('Vision', model.supportsVision),
            _buildCapabilityChip('Audio', model.supportsAudio),
            _buildCapabilityChip('Streaming', model.supportsStreaming),
            _buildCapabilityChip('Tool Calling', model.supportsToolCalling),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondaryColor)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCapabilityChip(String label, bool supported) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Chip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        backgroundColor: supported
            ? AppTheme.successColor.withOpacity(0.2)
            : AppTheme.surfaceColor,
        labelStyle: TextStyle(
          color:
              supported ? AppTheme.successColor : AppTheme.textSecondaryColor,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
