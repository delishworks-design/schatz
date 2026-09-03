import 'package:flutter/material.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/screens/home_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../settings/screens/provider_manager_screen.dart';
import '../../settings/screens/provider_editor_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../providers/screens/model_scanner_screen.dart';
import '../../providers/screens/model_selection_screen.dart';
import '../../providers/screens/provider_setup_screen.dart';
import '../../offline/screens/offline_model_manager_screen.dart';
import '../../offline/screens/model_download_screen.dart';
import '../../settings/screens/offline_mode_settings.dart';
import '../../plugins/screens/plugin_manager_screen.dart';
import '../../plugins/screens/plugin_marketplace_screen.dart';
import '../../plugins/screens/plugin_settings_screen.dart';
import '../../plugins/screens/plugin_detail_screen.dart';
import '../widgets/splash_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String settings = '/settings';
  static const String providerManager = '/provider-manager';
  static const String providerEditor = '/provider-editor';
  static const String providerSetup = '/provider-setup';
  static const String modelScanner = '/model-scanner';
  static const String modelSelection = '/model-selection';
  static const String offlineModels = '/offline-models';
  static const String modelDownload = '/model-download';
  static const String offlineSettings = '/offline-settings';
  static const String pluginManager = '/plugins';
  static const String pluginMarketplace = '/plugins/marketplace';
  static const String pluginSettings = '/plugin-settings';
  static const String pluginDetail = '/plugin-detail';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final name = settings.name ?? '';

    if (name == splash) {
      return MaterialPageRoute(builder: (_) => const SplashScreen());
    } else if (name == onboarding) {
      return MaterialPageRoute(builder: (_) => const OnboardingScreen());
    } else if (name == home) {
      return MaterialPageRoute(builder: (_) => const HomeScreen());
    } else if (name == chat) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: args?['conversationId'],
          initialPrompt: args?['initialPrompt'],
        ),
      );
    } else if (name == AppRouter.settings) {
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    } else if (name == providerManager) {
      return MaterialPageRoute(builder: (_) => const ProviderManagerScreen());
    } else if (name == providerEditor) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => ProviderEditorScreen(providerId: args?['providerId']),
      );
    } else if (name == providerSetup) {
      return MaterialPageRoute(builder: (_) => const ProviderSetupScreen());
    } else if (name == modelScanner) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => ModelScannerScreen(providerId: args?['providerId']),
      );
    } else if (name == modelSelection) {
      return MaterialPageRoute(builder: (_) => const ModelSelectionScreen());
    } else if (name == offlineModels) {
      return MaterialPageRoute(
          builder: (_) => const OfflineModelManagerScreen());
    } else if (name == modelDownload) {
      return MaterialPageRoute(builder: (_) => const ModelDownloadScreen());
    } else if (name == offlineSettings) {
      return MaterialPageRoute(builder: (_) => const OfflineModeSettings());
    } else if (name == pluginManager) {
      return MaterialPageRoute(builder: (_) => const PluginManagerScreen());
    } else if (name == pluginMarketplace) {
      return MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen());
    } else if (name == pluginSettings) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => PluginSettingsScreen(pluginId: args?['pluginId'] ?? ''),
      );
    } else if (name == pluginDetail) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => PluginDetailScreen(
          pluginId: args?['pluginId'] ?? '',
          isMarketplace: args?['isMarketplace'] ?? false,
        ),
      );
    }

    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text('No route defined for $name')),
      ),
    );
  }
}
