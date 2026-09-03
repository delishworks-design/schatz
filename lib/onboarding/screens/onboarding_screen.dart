import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../providers/models/provider_templates.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/models/starter_model_catalog.dart';
import '../../providers/services/provider_service.dart';
import '../../core/security/secure_storage.dart';
import '../../core/storage/storage_keys.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedProvider;
  final _apiKeyController = TextEditingController();
  bool _obscureText = true;
  ModelCostInfo? _selectedModel;

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(),
                  _buildProviderPage(),
                  _buildApiKeyPage(),
                  _buildModelPage(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.diamond, size: 60, color: Colors.black),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Schatz',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your premium AI companion, ready to chat. Configure your provider to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Choose a Provider',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select an AI provider to chat with',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: ProviderTemplates.templates.length,
              itemBuilder: (context, index) {
                final template = ProviderTemplates.templates[index];
                final isSelected = _selectedProvider == template.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.2)
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getProviderIcon(template.type),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                    title: Text(template.displayName),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      setState(() => _selectedProvider = template.id);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.key, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            'Enter API Key',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your API key is stored securely on your device',
            style: TextStyle(color: AppTheme.textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: 'Enter your API key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() => _obscureText = !_obscureText);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Skip for now if you want to set up later',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildModelPage() {
    if (_selectedProvider == null) {
      return const Center(
        child: Text(
          'Please select a provider first',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    final template = ProviderTemplates.templates.firstWhere(
      (t) => t.id == _selectedProvider,
    );
    final models = StarterModelCatalog.getStarterModels(template.type);

    if (_selectedModel == null && models.isNotEmpty) {
      _selectedModel = StarterModelCatalog.getDefaultStarterModel(template.type);
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            'Select a Model',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a default model for your chats',
            style: TextStyle(color: AppTheme.textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                final isSelected = _selectedModel?.modelId == model.modelId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : null,
                  child: ListTile(
                    leading: Icon(
                      _getCostIcon(model.costType),
                      color: _getCostColor(model.costType),
                    ),
                    title: Text(model.modelName),
                    subtitle: Text(
                      model.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppTheme.primaryColor)
                        : _getCostBadge(model.costType),
                    onTap: () {
                      setState(() {
                        _selectedModel = model;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Skip to use default model',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
          ),
        ],
      ),
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

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Back'),
            ),
          const Spacer(),
          ...List.generate(4, (index) => _buildDot(index)),
          const Spacer(),
          ElevatedButton(
            onPressed: _currentPage == 3 ? _completeOnboarding : _nextPage,
            child: Text(_currentPage == 3 ? 'Get Started' : 'Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index
            ? AppTheme.primaryColor
            : AppTheme.textSecondaryColor.withOpacity(0.3),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _completeOnboarding() async {
    final storage = SecureStorage();
    final providerService = ProviderService();

    if (_selectedProvider != null) {
      final template = ProviderTemplates.templates.firstWhere(
        (t) => t.id == _selectedProvider,
      );

      final profileId = 'profile_${const Uuid().v4()}';
      final apiKeyRef = StorageKeys.apiKeyReference(profileId);
      final starterModels = StarterModelCatalog.starterModelsToProviderModels(
        template.type,
        profileId,
      );
      final defaultModel = StarterModelCatalog.getDefaultStarterModel(template.type);
      final selectedModelId = _selectedModel?.modelId ?? defaultModel?.modelId;

      final profile = ProviderProfile(
        id: profileId,
        displayName: template.displayName,
        type: template.type,
        baseUrl: template.baseUrl,
        apiKeyReference: apiKeyRef,
        selectedModel: selectedModelId,
        availableModels: starterModels,
        streamingEnabled: template.streamingEnabled,
        visionEnabled: template.visionEnabled,
      );

      await providerService.saveProfile(profile);
      await storage.write(StorageKeys.activeProviderId, profileId);

      if (_apiKeyController.text.isNotEmpty) {
        await storage.writeApiKey(profileId, _apiKeyController.text);
      }
    }

    await storage.write(StorageKeys.onboardingComplete, 'true');

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  IconData _getProviderIcon(dynamic type) {
    return Icons.smart_toy;
  }
}
