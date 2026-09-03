import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../services/model_downloader.dart';

class OfflineModelManagerScreen extends StatefulWidget {
  const OfflineModelManagerScreen({super.key});

  @override
  State<OfflineModelManagerScreen> createState() =>
      _OfflineModelManagerScreenState();
}

class _OfflineModelManagerScreenState extends State<OfflineModelManagerScreen> {
  final ModelDownloader _downloader = ModelDownloader();
  List<DownloadedModel> _downloadedModels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final models = await _downloader.getDownloadedModels();
    setState(() {
      _downloadedModels = models;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Offline Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.pushNamed(context, '/model-download'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedModels.isEmpty
              ? _buildEmptyState()
              : _buildModelList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.offline_bolt,
            size: 80,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No offline models',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Download models to use Schatz without internet',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/model-download'),
            icon: const Icon(Icons.download),
            label: const Text('Download Model'),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _downloadedModels.length,
      itemBuilder: (context, index) {
        final model = _downloadedModels[index];
        return _buildModelCard(model);
      },
    );
  }

  Widget _buildModelCard(DownloadedModel model) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.offline_bolt,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        model.size,
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value, model),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'use', child: Text('Use Model')),
                    const PopupMenuItem(value: 'info', child: Text('Details')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: AppTheme.errorColor)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildModelInfo(model),
          ],
        ),
      ),
    );
  }

  Widget _buildModelInfo(DownloadedModel model) {
    final contextDisplay = model.contextLength >= 1024
        ? '${(model.contextLength / 1024).toStringAsFixed(0)}K'
        : '${model.contextLength}';

    return Row(
      children: [
        _buildInfoChip('${model.quantization}', Icons.memory),
        const SizedBox(width: 8),
        _buildInfoChip('$contextDisplay context', Icons.straighten),
        const SizedBox(width: 8),
        _buildInfoChip('${model.ramRequired}GB RAM', Icons.speed),
      ],
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, DownloadedModel model) {
    switch (action) {
      case 'use':
        _useModel(model);
        break;
      case 'info':
        _showModelDetails(model);
        break;
      case 'delete':
        _deleteModel(model);
        break;
    }
  }

  // TODO: Actual model loading requires InferenceService integration.
  void _useModel(DownloadedModel model) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${model.name} set as active offline model')),
    );
  }

  void _showModelDetails(DownloadedModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('File Size', model.size),
            _buildDetailRow('Quantization', model.quantization),
            _buildDetailRow('Context Length',
                '${model.contextLength >= 1024 ? (model.contextLength / 1024).toStringAsFixed(0) + "K" : model.contextLength} tokens'),
            _buildDetailRow('RAM Required', '${model.ramRequired}GB'),
            _buildDetailRow(
                'Downloaded', model.downloadedAt.toString().substring(0, 10)),
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

  void _deleteModel(DownloadedModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Delete "${model.name}"?'),
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
      await _downloader.deleteModel(model.id);
      _loadModels();
    }
  }
}
