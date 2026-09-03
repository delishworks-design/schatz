import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/secure_storage.dart';
import '../../offline/services/inference_service.dart';
import '../../offline/services/model_downloader.dart';

class OfflineModeSettings extends StatefulWidget {
  const OfflineModeSettings({super.key});
  
  @override
  State<OfflineModeSettings> createState() => _OfflineModeSettingsState();
}

class _OfflineModeSettingsState extends State<OfflineModeSettings> {
  final SecureStorage _storage = SecureStorage();
  final InferenceService _inferenceService = InferenceService();
  final ModelDownloader _downloader = ModelDownloader();
  
  bool _offlineModeEnabled = false;
  String? _selectedModelId;
  List<DownloadedModel> _downloadedModels = [];
  double _temperature = 0.7;
  int _maxTokens = 1024;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final offlineMode = await _storage.read('offline_mode');
    final selectedModel = await _storage.read('selected_offline_model');
    final models = await _downloader.getDownloadedModels();
    
    if (!mounted) return;
    setState(() {
      _offlineModeEnabled = offlineMode == 'true';
      _selectedModelId = selectedModel;
      _downloadedModels = models;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Offline Mode'),
      ),
      body: ListView(
        children: [
          _buildOfflineModeToggle(),
          _buildModelSelection(),
          _buildInferenceSettings(),
          _buildInfoSection(),
        ],
      ),
    );
  }
  
  Widget _buildOfflineModeToggle() {
    return SwitchListTile(
      title: const Text('Enable Offline Mode'),
      subtitle: const Text('Use local models without internet'),
      value: _offlineModeEnabled,
      onChanged: (value) async {
        setState(() => _offlineModeEnabled = value);
        await _storage.write('offline_mode', value.toString());
      },
      thumbColor: WidgetStateProperty.all(AppTheme.primaryColor),
    );
  }
  
  Widget _buildModelSelection() {
    return _buildSection('Model Selection', [
      if (_downloadedModels.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No offline models downloaded',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
        )
      else
        ..._downloadedModels.map((model) => RadioListTile<String>(
          title: Text(model.name),
          subtitle: Text('${model.size} • ${model.quantization}'),
          value: model.id,
          groupValue: _selectedModelId,
          onChanged: (value) async {
            setState(() => _selectedModelId = value);
            await _storage.write('selected_offline_model', value ?? '');
          },
          activeColor: AppTheme.primaryColor,
        )),
      if (_downloadedModels.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/model-download'),
            icon: const Icon(Icons.download),
            label: const Text('Download More Models'),
          ),
        ),
    ]);
  }
  
  Widget _buildInferenceSettings() {
    return _buildSection('Inference Settings', [
      ListTile(
        title: const Text('Temperature'),
        subtitle: Slider(
          value: _temperature,
          min: 0.0,
          max: 2.0,
          divisions: 20,
          label: _temperature.toStringAsFixed(1),
          onChanged: (value) {
            setState(() => _temperature = value);
          },
        ),
        trailing: Text(_temperature.toStringAsFixed(1)),
      ),
      ListTile(
        title: const Text('Max Tokens'),
        subtitle: Slider(
          value: _maxTokens.toDouble(),
          min: 256,
          max: 4096,
          divisions: 15,
          label: _maxTokens.toString(),
          onChanged: (value) {
            setState(() => _maxTokens = value.round());
          },
        ),
        trailing: Text(_maxTokens.toString()),
      ),
    ]);
  }
  
  Widget _buildInfoSection() {
    return _buildSection('About Offline Mode', [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline mode allows you to use Schatz without an internet connection by running AI models locally on your device.',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            SizedBox(height: 12),
            Text(
              'Requirements:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• Sufficient RAM for the model size'),
            Text('• Storage space for model files'),
            Text('• Compatible device (Android 7+)'),
            SizedBox(height: 12),
            Text(
              'Note: Offline models may be slower and less capable than cloud providers.',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ]);
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
