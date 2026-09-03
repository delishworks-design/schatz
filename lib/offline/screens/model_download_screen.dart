import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../services/model_downloader.dart';

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});
  
  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  final ModelDownloader _downloader = ModelDownloader();
  List<AvailableModel> _availableModels = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  
  @override
  void initState() {
    super.initState();
    _loadAvailableModels();
  }
  
  Future<void> _loadAvailableModels() async {
    setState(() => _isLoading = true);
    final models = await _downloader.getAvailableModels();
    setState(() {
      _availableModels = models;
      _isLoading = false;
    });
  }
  
  List<AvailableModel> get _filteredModels {
    if (_selectedCategory == 'all') return _availableModels;
    return _availableModels.where((m) => m.category == _selectedCategory).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Download Models'),
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildModelList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Small', 'small'),
          _buildFilterChip('Medium', 'medium'),
          _buildFilterChip('Large', 'large'),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = category);
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }
  
  Widget _buildModelList() {
    if (_filteredModels.isEmpty) {
      return const Center(
        child: Text('No models available', style: TextStyle(color: AppTheme.textSecondaryColor)),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredModels.length,
      itemBuilder: (context, index) {
        final model = _filteredModels[index];
        return _buildModelCard(model);
      },
    );
  }
  
  Widget _buildModelCard(AvailableModel model) {
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
                  child: const Icon(Icons.cloud_download, color: AppTheme.primaryColor),
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
                        model.description,
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildModelSpecs(model),
            const SizedBox(height: 12),
            _buildDownloadButton(model),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModelSpecs(AvailableModel model) {
    final contextDisplay = model.contextLength >= 1024 
        ? '${(model.contextLength / 1024).toStringAsFixed(0)}K'
        : '${model.contextLength}';
    
    return Row(
      children: [
        _buildSpecChip('${model.sizeGB}GB', Icons.storage),
        const SizedBox(width: 8),
        _buildSpecChip('${model.quantization}', Icons.memory),
        const SizedBox(width: 8),
        _buildSpecChip(contextDisplay, Icons.straighten),
        const SizedBox(width: 8),
        _buildSpecChip('${model.ramRequired}GB RAM', Icons.speed),
      ],
    );
  }
  
  Widget _buildSpecChip(String label, IconData icon) {
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
  
  Widget _buildDownloadButton(AvailableModel model) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _downloadModel(model),
        icon: const Icon(Icons.download),
        label: const Text('Download'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
  
  void _downloadModel(AvailableModel model) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Model'),
        content: Text('Download "${model.name}"?\n\nThis may take a while depending on your connection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startDownload(model);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
  
  void _startDownload(AvailableModel model) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting download: ${model.name}')),
    );

    try {
      await _downloader.downloadModel(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download complete: ${model.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
