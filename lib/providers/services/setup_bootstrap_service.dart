import '../models/provider_profile.dart';
import '../services/provider_service.dart';
import '../../core/security/secure_storage.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/storage/key_migration_service.dart';

enum SetupStatus {
  needsOnboarding,
  needsProvider,
  needsApiKey,
  needsModel,
  needsConnectionCheck,
  ready,
}

class SetupReadinessResult {
  final SetupStatus status;
  final ProviderProfile? activeProvider;
  final String? activeProviderId;
  final String? selectedModel;
  final int availableModelCount;
  final bool hasApiKey;
  final String message;

  SetupReadinessResult({
    required this.status,
    this.activeProvider,
    this.activeProviderId,
    this.selectedModel,
    this.availableModelCount = 0,
    this.hasApiKey = false,
    required this.message,
  });

  bool get isComplete => status == SetupStatus.ready;
  bool get needsSetup => status != SetupStatus.ready && status != SetupStatus.needsOnboarding;
}

class SetupBootstrapService {
  final SecureStorage _storage = SecureStorage();
  final ProviderService _providerService = ProviderService();
  final KeyMigrationService _migrationService = KeyMigrationService();

  Future<SetupReadinessResult> checkReadiness() async {
    await _migrationService.runMigrations();

    final onboardingComplete = await _storage.read(StorageKeys.onboardingComplete);

    if (onboardingComplete != 'true') {
      return SetupReadinessResult(
        status: SetupStatus.needsOnboarding,
        message: 'Onboarding not complete',
      );
    }

    final activeProviderId = await _storage.read(StorageKeys.activeProviderId);

    if (activeProviderId == null || activeProviderId.isEmpty) {
      return SetupReadinessResult(
        status: SetupStatus.needsProvider,
        message: 'No active provider selected',
      );
    }

    final profiles = await _providerService.getProfiles();
    final activeProvider = profiles.where((p) => p.id == activeProviderId).firstOrNull;

    if (activeProvider == null) {
      return SetupReadinessResult(
        status: SetupStatus.needsProvider,
        message: 'Active provider not found',
      );
    }

    final hasApiKey = await _storage.containsKey(
      StorageKeys.apiKeyReference(activeProviderId),
    );

    if (!hasApiKey) {
      return SetupReadinessResult(
        status: SetupStatus.needsApiKey,
        activeProvider: activeProvider,
        activeProviderId: activeProviderId,
        selectedModel: activeProvider.selectedModel,
        availableModelCount: activeProvider.availableModels.length,
        hasApiKey: false,
        message: 'API key not configured for ${activeProvider.displayName}',
      );
    }

    if (activeProvider.selectedModel == null || activeProvider.selectedModel!.isEmpty) {
      return SetupReadinessResult(
        status: SetupStatus.needsModel,
        activeProvider: activeProvider,
        activeProviderId: activeProviderId,
        selectedModel: activeProvider.selectedModel,
        availableModelCount: activeProvider.availableModels.length,
        hasApiKey: true,
        message: 'No model selected for ${activeProvider.displayName}',
      );
    }

    if (activeProvider.availableModels.isEmpty) {
      return SetupReadinessResult(
        status: SetupStatus.needsConnectionCheck,
        activeProvider: activeProvider,
        activeProviderId: activeProviderId,
        selectedModel: activeProvider.selectedModel,
        availableModelCount: 0,
        hasApiKey: true,
        message: 'No models available - connection check needed',
      );
    }

    return SetupReadinessResult(
      status: SetupStatus.ready,
      activeProvider: activeProvider,
      activeProviderId: activeProviderId,
      selectedModel: activeProvider.selectedModel,
      availableModelCount: activeProvider.availableModels.length,
      hasApiKey: true,
      message: 'Ready',
    );
  }

  Future<bool> hasCompletedOnboarding() async {
    final onboardingComplete = await _storage.read(StorageKeys.onboardingComplete);
    return onboardingComplete == 'true';
  }

  Future<String?> getActiveProviderId() async {
    return await _storage.read(StorageKeys.activeProviderId);
  }

  Future<ProviderProfile?> getActiveProvider() async {
    final activeProviderId = await getActiveProviderId();
    if (activeProviderId == null) return null;

    final profiles = await _providerService.getProfiles();
    return profiles.where((p) => p.id == activeProviderId).firstOrNull;
  }

  Future<bool> isApiKeyConfigured(String providerId) async {
    return await _storage.containsKey(StorageKeys.apiKeyReference(providerId));
  }

  Future<void> setActiveProvider(String providerId) async {
    await _storage.write(StorageKeys.activeProviderId, providerId);
  }

  Future<void> markOnboardingComplete() async {
    await _storage.write(StorageKeys.onboardingComplete, 'true');
  }

  Future<void> clearOnboarding() async {
    await _storage.write(StorageKeys.onboardingComplete, 'false');
  }
}
