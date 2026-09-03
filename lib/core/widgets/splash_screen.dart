import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../routing/app_router.dart';
import '../security/secure_storage.dart';
import '../../providers/services/setup_bootstrap_service.dart';
import '../../core/storage/storage_keys.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  SetupReadinessResult? _readinessResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _bootstrapAndNavigate();
  }

  Future<void> _bootstrapAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final bootstrapService = SetupBootstrapService();
    final result = await bootstrapService.checkReadiness();

    if (!mounted) return;

    setState(() {
      _readinessResult = result;
      _isLoading = false;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    final storage = SecureStorage();
    final onboardingComplete = await storage.read(StorageKeys.onboardingComplete);
    final setupSkipped = await storage.read('setup_skipped');

    if (!mounted) return;

    final result = _readinessResult;

    if (onboardingComplete != 'true' && setupSkipped != 'true') {
      Navigator.pushReplacementNamed(context, AppRouter.onboarding);
    } else if (result == null || result.status == SetupStatus.needsOnboarding) {
      Navigator.pushReplacementNamed(context, AppRouter.onboarding);
    } else if (result.status == SetupStatus.needsProvider ||
        result.status == SetupStatus.needsApiKey ||
        result.status == SetupStatus.needsModel ||
        result.status == SetupStatus.needsConnectionCheck) {
      Navigator.pushReplacementNamed(context, AppRouter.providerSetup);
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 24),
                _buildTitle(),
                const SizedBox(height: 8),
                _buildSubtitle(),
                if (!_isLoading) ...[
                  const SizedBox(height: 32),
                  _buildReadinessCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.diamond,
        size: 50,
        color: Colors.black,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Schatz',
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Your AI Companion',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
    );
  }

  Widget _buildReadinessCard() {
    final result = _readinessResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusRow(result),
          if (result.activeProvider != null) ...[
            const Divider(height: 24),
            _buildProviderRow(result),
            if (result.selectedModel != null) ...[
              const SizedBox(height: 8),
              _buildModelRow(result),
            ],
          ],
          if (result.availableModelCount > 0) ...[
            const SizedBox(height: 8),
            _buildModelCountRow(result),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(SetupReadinessResult result) {
    final (statusText, statusColor, statusIcon) = _getStatusInfo(result.status);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 8),
        Icon(statusIcon, size: 16, color: statusColor),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProviderRow(SetupReadinessResult result) {
    return Row(
      children: [
        const Icon(Icons.dns, size: 14, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            result.activeProvider!.displayName,
            style: const TextStyle(
              color: AppTheme.textColor,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildModelRow(SetupReadinessResult result) {
    return Row(
      children: [
        const Icon(Icons.smart_toy, size: 14, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            result.selectedModel!,
            style: const TextStyle(
              color: AppTheme.textColor,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildModelCountRow(SetupReadinessResult result) {
    return Row(
      children: [
        const Icon(Icons.list, size: 14, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Text(
          '${result.availableModelCount} models available',
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  (String, Color, IconData) _getStatusInfo(SetupStatus status) {
    switch (status) {
      case SetupStatus.ready:
        return ('Ready', AppTheme.successColor, Icons.check_circle);
      case SetupStatus.needsOnboarding:
        return ('Needs Setup', Colors.orange, Icons.person_add);
      case SetupStatus.needsProvider:
        return ('Needs Provider', Colors.orange, Icons.dns_outlined);
      case SetupStatus.needsApiKey:
        return ('Needs API Key', Colors.orange, Icons.key);
      case SetupStatus.needsModel:
        return ('Needs Model', Colors.orange, Icons.smart_toy_outlined);
      case SetupStatus.needsConnectionCheck:
        return ('Needs Connection', Colors.orange, Icons.wifi_find);
    }
  }
}
