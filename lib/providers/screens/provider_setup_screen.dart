import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../core/security/secure_storage.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/models/provider_templates.dart';
import '../../providers/models/starter_model_catalog.dart';
import '../../providers/services/provider_service.dart';
import '../../providers/services/setup_bootstrap_service.dart';
import '../../core/storage/storage_keys.dart';

class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({super.key});

  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final SecureStorage _storage = SecureStorage();
  final ProviderService _providerService = ProviderService();
  final SetupBootstrapService _bootstrapService = SetupBootstrapService();

  int _currentStep = 0;
  String? _selectedProviderType;
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  SetupStatus? _currentStatus;
  String? _selectedModelId;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _checkSetupStatus() async {
    final result = await _bootstrapService.checkReadiness();
    if (!mounted) return;
    setState(() {
      _currentStatus = result.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Provider Setup'),
        automaticallyImplyLeading: false,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: _buildControls,
        steps: [
          Step(
            title: const Text('Select Provider'),
            subtitle: _selectedProviderType != null
                ? Text(ProviderType.values.firstWhere((t) => t.name == _selectedProviderType).name)
                : null,
            content: _buildProviderSelection(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Enter API Key'),
            subtitle: _apiKeyController.text.isNotEmpty
                ? const Text('API key entered')
                : null,
            content: _buildApiKeyEntry(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Configure Model'),
            content: _buildModelConfiguration(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (details.stepIndex < 2)
            ElevatedButton(
              onPressed: details.onStepContinue,
              child: const Text('Continue'),
            )
          else
            ElevatedButton(
              onPressed: _isLoading ? null : _completeSetup,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Complete Setup'),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: details.onStepCancel,
            child: const Text('Back'),
          ),
          const Spacer(),
          TextButton(
            onPressed: _skipSetup,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose an AI provider to get started. You can change this later.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 16),
        ...ProviderType.values.where((t) => t != ProviderType.custom).map((type) {
          final isSelected = _selectedProviderType == type.name;
          final starterInfo = StarterModelCatalog.getDefaultStarterModel(type);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
            child: ListTile(
              leading: Icon(
                _getProviderIcon(type),
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              ),
              title: Text(ProviderTemplates.templates
                  .firstWhere((t) => t.type == type, orElse: () => ProviderProfile(
                        displayName: type.name,
                        type: type,
                        baseUrl: '',
                        apiKeyReference: '',
                      ))
                  .displayName),
              subtitle: _buildProviderSubtitle(type, starterInfo),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                setState(() {
                  _selectedProviderType = type.name;
                  _error = null;
                });
              },
            ),
          );
        }),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
      ],
    );
  }

  Widget _buildProviderSubtitle(ProviderType type, ModelCostInfo? starterInfo) {
    if (starterInfo == null) {
      return const Text('No starter models available');
    }

    final costLabel = _getCostLabel(starterInfo.costType);
    return Text(
      '${starterInfo.modelName} ($costLabel)',
      style: const TextStyle(fontSize: 12),
    );
  }

  String _getCostLabel(ModelCostType costType) {
    switch (costType) {
      case ModelCostType.free:
        return 'Free';
      case ModelCostType.starter:
        return 'Starter';
      case ModelCostType.trial:
        return 'Trial';
      case ModelCostType.paid:
        return 'Paid';
      case ModelCostType.unknown:
        return 'Unknown';
    }
  }

  Widget _buildApiKeyEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your API key for ${_selectedProviderType ?? 'the selected provider'}. '
          'Your key is stored securely on your device.',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'Enter your API key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can skip this step and enter the key later from settings.',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildModelConfiguration() {
    if (_selectedProviderType == null) {
      return const Text('Please select a provider first');
    }

    final type = ProviderType.values.firstWhere((t) => t.name == _selectedProviderType);
    final starterModels = StarterModelCatalog.getStarterModels(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a model to use as your default. You can change this later.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 16),
        if (starterModels.isEmpty)
          const Text('No starter models available for this provider')
        else
          ...starterModels.map((model) {
            final isSelected = _selectedModelId == model.modelId;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
              child: ListTile(
                leading: Icon(
                  _getCostIcon(model.costType),
                  color: _getCostColor(model.costType),
                ),
                title: Text(model.modelName),
                subtitle: Text(
                  '${model.description}${model.contextLength != null ? ' • ${model.contextLength! ~/ 1000}K context' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : _getCostBadge(model.costType),
                onTap: () {
                  setState(() {
                    _selectedModelId = model.modelId;
                  });
                },
              ),
            );
          }),
      ],
    );
  }

  IconData _getCostIcon(ModelCostType costType) {
    switch (costType) {
      case ModelCostType.free:
        return Icons.wifi_find;
      case ModelCostType.starter:
        return Icons.star;
      case ModelCostType.trial:
        return Icons.access_time;
      case ModelCostType.paid:
        return Icons.paid;
      case ModelCostType.unknown:
        return Icons.help;
    }
  }

  Color _getCostColor(ModelCostType costType) {
    switch (costType) {
      case ModelCostType.free:
        return AppTheme.successColor;
      case ModelCostType.starter:
        return AppTheme.primaryColor;
      case ModelCostType.trial:
        return Colors.orange;
      case ModelCostType.paid:
        return Colors.red;
      case ModelCostType.unknown:
        return AppTheme.textSecondaryColor;
    }
  }

  Widget? _getCostBadge(ModelCostType costType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getCostColor(costType).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getCostLabel(costType),
        style: TextStyle(
          color: _getCostColor(costType),
          fontSize: 10,
          fontWeight: FontWeight.w600,
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

  void _onStepContinue() {
    if (_currentStep == 0 && _selectedProviderType == null) {
      setState(() => _error = 'Please select a provider');
      return;
    }
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        _error = null;
        if (_currentStep == 2 && _selectedModelId == null) {
          final type = ProviderType.values.firstWhere((t) => t.name == _selectedProviderType);
          _selectedModelId = StarterModelCatalog.getDefaultStarterModel(type)?.modelId;
        }
      });
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _error = null;
      });
    }
  }

  Future<void> _completeSetup() async {
    if (_selectedProviderType == null) return;

    setState(() => _isLoading = true);

    try {
      final type = ProviderType.values.firstWhere((t) => t.name == _selectedProviderType);
      final template = ProviderTemplates.getTemplateByType(type);

      if (template == null) {
        setState(() => _isLoading = false);
        return;
      }

      final profileId = 'profile_${DateTime.now().millisecondsSinceEpoch}';
      final apiKeyRef = StorageKeys.apiKeyReference(profileId);

      final starterModels = StarterModelCatalog.starterModelsToProviderModels(type, profileId);
      final defaultModel = StarterModelCatalog.getDefaultStarterModel(type);

      final profile = ProviderProfile(
        id: profileId,
        displayName: template.displayName,
        type: type,
        baseUrl: template.baseUrl,
        apiKeyReference: apiKeyRef,
        selectedModel: _selectedModelId ?? defaultModel?.modelId,
        availableModels: starterModels,
        temperature: template.temperature,
        maxTokens: template.maxTokens,
        streamingEnabled: template.streamingEnabled,
        visionEnabled: template.visionEnabled,
      );

      await _providerService.saveProfile(profile);
      await _storage.write(StorageKeys.activeProviderId, profileId);

      if (_apiKeyController.text.isNotEmpty) {
        await _storage.writeApiKey(apiKeyRef, _apiKeyController.text);
      }

      await _storage.write(StorageKeys.onboardingComplete, 'true');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.home);
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: $e')),
      );
    }
  }

  Future<void> _skipSetup() async {
    await _storage.write('setup_skipped', 'true');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }
}
