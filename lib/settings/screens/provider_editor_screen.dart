import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/models/provider_profile.dart';
import '../../core/security/secure_storage.dart';
import '../../providers/services/provider_service.dart';

class ProviderEditorScreen extends StatefulWidget {
  final String? providerId;

  const ProviderEditorScreen({super.key, this.providerId});

  @override
  State<ProviderEditorScreen> createState() => _ProviderEditorScreenState();
}

class _ProviderEditorScreenState extends State<ProviderEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  ProviderType _selectedType = ProviderType.openai;
  String? _selectedModel;
  double _temperature = 0.7;
  int _maxTokens = 4096;
  bool _streamingEnabled = true;
  List<String> _availableModels = [];
  bool _isLoadingModels = false;

  @override
  void initState() {
    super.initState();
    if (widget.providerId != null) {
      _loadProvider();
    }
  }

  void _loadProvider() async {
    final profiles = await ProviderService().getProfiles();
    if (!mounted) return;
    try {
      final profile = profiles.firstWhere(
        (p) => p.id == widget.providerId,
        orElse: () => profiles.isNotEmpty ? profiles.first : null!,
      );
      setState(() {
        _nameController.text = profile.displayName;
        _urlController.text = profile.baseUrl;
        _selectedType = profile.type;
        _selectedModel = profile.selectedModel;
        _temperature = profile.temperature;
        _maxTokens = profile.maxTokens;
        _streamingEnabled = profile.streamingEnabled;
      });
    } catch (_) {
      setState(() {
        _nameController.text = 'My Provider';
        _urlController.text = 'https://api.openai.com/v1';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title:
            Text(widget.providerId != null ? 'Edit Provider' : 'Add Provider'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('Provider Type', [
              DropdownButtonFormField<ProviderType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: ProviderType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                    _updateDefaultUrl(value);
                  }
                },
              ),
            ]),
            _buildSection('Configuration', [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'My Provider',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ]),
            _buildSection('Model', [
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                items: _availableModels.map((model) {
                  return DropdownMenuItem(
                    value: model,
                    child: Text(model),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedModel = value);
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchModels,
                icon: const Icon(Icons.refresh),
                label: const Text('Fetch Available Models'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ]),
            _buildSection('Parameters', [
              Row(
                children: [
                  const Text('Temperature: '),
                  Expanded(
                    child: Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      label: _temperature.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() => _temperature = value);
                      },
                    ),
                  ),
                  Text(_temperature.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Max Tokens: '),
                  Expanded(
                    child: Slider(
                      value: _maxTokens.toDouble(),
                      min: 256,
                      max: 8192,
                      divisions: 31,
                      label: _maxTokens.toString(),
                      onChanged: (value) {
                        setState(() => _maxTokens = value.round());
                      },
                    ),
                  ),
                  Text(_maxTokens.toString()),
                ],
              ),
              SwitchListTile(
                title: const Text('Streaming'),
                subtitle: const Text('Enable real-time streaming'),
                value: _streamingEnabled,
                onChanged: (value) {
                  setState(() => _streamingEnabled = value);
                },
                thumbColor: WidgetStateProperty.all(AppTheme.primaryColor),
              ),
            ]),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.wifi_find),
              label: const Text('Test Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
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

  void _updateDefaultUrl(ProviderType type) {
    switch (type) {
      case ProviderType.openai:
        _urlController.text = 'https://api.openai.com/v1';
        break;
      case ProviderType.gemini:
        _urlController.text =
            'https://generativelanguage.googleapis.com/v1beta';
        break;
      case ProviderType.groq:
        _urlController.text = 'https://api.groq.com/openai/v1';
        break;
      case ProviderType.openrouter:
        _urlController.text = 'https://openrouter.ai/api/v1';
        break;
      case ProviderType.mistral:
        _urlController.text = 'https://api.mistral.ai/v1';
        break;
      case ProviderType.cerebras:
        _urlController.text = 'https://api.cerebras.ai/v1';
        break;
      case ProviderType.custom:
        _urlController.text = '';
        break;
    }
  }

  void _fetchModels() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a base URL first')),
      );
      return;
    }

    setState(() => _isLoadingModels = true);

    final profile = ProviderProfile(
      displayName: _nameController.text,
      type: _selectedType,
      baseUrl: _urlController.text,
      apiKeyReference: _selectedType.name,
    );

    try {
      final models = await ProviderService().listModels(profile);
      setState(() {
        _availableModels = models.map((m) => m.id).toList();
        _isLoadingModels = false;
      });

      if (_availableModels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No models found')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${_availableModels.length} models')),
        );
      }
    } catch (e) {
      setState(() => _isLoadingModels = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch models: $e')),
      );
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final profile = ProviderProfile(
        id: widget.providerId,
        displayName: _nameController.text,
        type: _selectedType,
        baseUrl: _urlController.text,
        apiKeyReference: _selectedType.name,
        selectedModel: _selectedModel,
        temperature: _temperature,
        maxTokens: _maxTokens,
        streamingEnabled: _streamingEnabled,
      );
      await ProviderService().saveProfile(profile);
      if (_apiKeyController.text.isNotEmpty) {
        await SecureStorage()
            .writeApiKey(profile.apiKeyReference, _apiKeyController.text);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  void _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...')),
    );

    final profile = ProviderProfile(
      displayName: _nameController.text,
      type: _selectedType,
      baseUrl: _urlController.text,
      apiKeyReference: _selectedType.name,
      selectedModel: _selectedModel,
    );

    if (_apiKeyController.text.isNotEmpty) {
      await SecureStorage()
          .writeApiKey(profile.apiKeyReference, _apiKeyController.text);
    }

    try {
      final result = await ProviderService().testConnection(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor:
                result.success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Connection failed: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}
