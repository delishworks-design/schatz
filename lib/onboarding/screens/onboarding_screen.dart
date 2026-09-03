import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../providers/models/provider_templates.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/services/provider_service.dart';
import '../../core/security/secure_storage.dart';

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
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter your API key',
              border: OutlineInputBorder(),
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
          ...List.generate(3, (index) => _buildDot(index)),
          const Spacer(),
          ElevatedButton(
            onPressed: _currentPage == 2 ? _completeOnboarding : _nextPage,
            child: Text(_currentPage == 2 ? 'Get Started' : 'Next'),
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
    await storage.write('onboarding_complete', 'true');

    if (_selectedProvider != null) {
      final template = ProviderTemplates.templates.firstWhere(
        (t) => t.id == _selectedProvider,
      );

      final profile = ProviderProfile(
        displayName: template.displayName,
        type: template.type,
        baseUrl: template.baseUrl,
        apiKeyReference: template.apiKeyReference,
        streamingEnabled: template.streamingEnabled,
        visionEnabled: template.visionEnabled,
      );

      await providerService.saveProfile(profile);
      await storage.write('active_provider_id', profile.id);

      if (_apiKeyController.text.isNotEmpty) {
        await storage.writeApiKey(
            template.apiKeyReference, _apiKeyController.text);
      }
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  IconData _getProviderIcon(dynamic type) {
    return Icons.smart_toy;
  }
}
