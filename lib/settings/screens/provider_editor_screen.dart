import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/models/provider_profile.dart';
import '../../core/security/secure_storage.dart';
import '../../providers/services/provider_service.dart';
import '../../core/storage/storage_keys.dart';

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
  double _topP = 1.0;
  bool _streamingEnabled = true;
  bool _visionEnabled = false;
  bool _toolCallingEnabled = false;
  List<ProviderModel> _availableModels = [];
  bool _isLoadingModels = false;
  String? _currentProfileId;
  String? _currentApiKeyRef;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    if (widget.providerId != null) {
      final profiles = await ProviderService().getProfiles();
      if (!mounted) return;
      final match = profiles.where((p) => p.id == widget.providerId).toList();
      if (match.isNotEmpty) {
        final profile = match.first;
        _populateFromProfile(profile);
      }
    }
    setState(() => _isLoading = false);
  }

  void _populateFromProfile(ProviderProfile profile) {
    setState(() {
      _currentProfileId = profile.id;
      _currentApiKeyRef = profile.apiKeyReference;
      _nameController.text = profile.displayName;
      _urlController.text = profile.baseUrl;
      _selectedType = profile.type;
      _selectedModel = profile.selectedModel;
      _temperature = profile.temperature;
      _maxTokens = profile.maxTokens;
      _topP = profile.topP;
      _streamingEnabled = profile.streamingEnabled;
      _visionEnabled = profile.visionEnabled;
      _toolCallingEnabled = profile.toolCallingEnabled;
      _availableModels = profile.availableModels;
    });
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_currentProfileId != null ? 'Edit Provider' : 'Add Provider'),
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
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  border: const OutlineInputBorder(),
                  helperText: _currentProfileId != null
                      ? 'Leave empty to keep existing key'
                      : 'Enter API key for this provider',
                ),
                obscureText: true,
              ),
            ]),
            _buildSection('Model', [
              DropdownButtonFormField<String>(
                value: _availableModels.any((m) => m.id == _selectedModel)
                    ? _selectedModel
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Select a model'),
                  ),
                  ..._availableModels.map((model) {
                    return DropdownMenuItem(
                      value: model.id,
                      child: Text(model.name),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedModel = value);
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoadingModels ? null : _fetchModels,
                icon: _isLoadingModels
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isLoadingModels ? 'Fetching...' : 'Fetch Available Models'),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Top P: '),
                  Expanded(
                    child: Slider(
                      value: _topP,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: _topP.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() => _topP = value);
                      },
                    ),
                  ),
                  Text(_topP.toStringAsFixed(1)),
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
              SwitchListTile(
                title: const Text('Vision'),
                subtitle: const Text('Enable image analysis'),
                value: _visionEnabled,
                onChanged: (value) {
                  setState(() => _visionEnabled = value);
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
        _urlController.text = 'https://generativelanguage.googleapis.com/v1beta';
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

  Future<void> _fetchModels() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a base URL first')),
      );
      return;
    }

    setState(() => _isLoadingModels = true);

    final profile = _buildProfileForTest();

    String? tempApiKey;
    if (_apiKeyController.text.isNotEmpty) {
      tempApiKey = _apiKeyController.text;
    }

    try {
      final models = await ProviderService().listModels(
        profile,
        apiKeyOverride: tempApiKey,
      );
      setState(() {
        _availableModels = models;
        if (_selectedModel == null && models.isNotEmpty) {
          _selectedModel = models.first.id;
        }
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

  ProviderProfile _buildProfileForTest() {
    final profileId = _currentProfileId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    return ProviderProfile(
      id: profileId,
      displayName: _nameController.text,
      type: _selectedType,
      baseUrl: _urlController.text,
      apiKeyReference: _currentApiKeyRef ?? profileId,
      selectedModel: _selectedModel,
      availableModels: _availableModels,
      temperature: _temperature,
      maxTokens: _maxTokens,
      topP: _topP,
      streamingEnabled: _streamingEnabled,
      visionEnabled: _visionEnabled,
      toolCallingEnabled: _toolCallingEnabled,
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final profileId = _currentProfileId ?? 'profile_${DateTime.now().millisecondsSinceEpoch}';
      final apiKeyRef = StorageKeys.apiKeyReference(profileId);

      final profile = ProviderProfile(
        id: profileId,
        displayName: _nameController.text,
        type: _selectedType,
        baseUrl: _urlController.text,
        apiKeyReference: apiKeyRef,
        selectedModel: _selectedModel,
        availableModels: _availableModels,
        temperature: _temperature,
        maxTokens: _maxTokens,
        topP: _topP,
        streamingEnabled: _streamingEnabled,
        visionEnabled: _visionEnabled,
        toolCallingEnabled: _toolCallingEnabled,
      );

      await ProviderService().saveProfile(profile);

      if (_apiKeyController.text.isNotEmpty) {
        await SecureStorage().writeApiKey(apiKeyRef, _apiKeyController.text);
      }

      if (mounted) Navigator.pop(context);
    }
  }

  void _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...')),
    );

    final profile = _buildProfileForTest();

    String? tempApiKey;
    if (_apiKeyController.text.isNotEmpty) {
      tempApiKey = _apiKeyController.text;
    }

    try {
      final result = await ProviderService().testConnection(
        profile,
        apiKeyOverride: tempApiKey,
      );
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
