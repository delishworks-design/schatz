import 'dart:convert';
import '../models/plugin.dart';
import '../models/tool.dart';
import '../../core/security/secure_storage.dart';
import 'tool_registry.dart';
import 'tool_executor.dart';
import '../integrations/github/github_plugin.dart';
import '../integrations/vercel/vercel_plugin.dart';
import '../integrations/supabase/supabase_plugin.dart';
import '../integrations/termux/termux_plugin.dart';
import '../integrations/railway/railway_plugin.dart';
import '../integrations/netlify/netlify_plugin.dart';
import '../integrations/stripe/stripe_plugin.dart';
import '../integrations/firebase/firebase_plugin.dart';
import '../integrations/cloudflare/cloudflare_plugin.dart';

class PluginService {
  static final PluginService _instance = PluginService._();
  factory PluginService() => _instance;
  PluginService._();

  final SecureStorage _storage = SecureStorage();
  final ToolRegistry _toolRegistry = ToolRegistry();
  final ToolExecutorService _toolExecutor = ToolExecutorService();
  bool _initialized = false;

  static final Map<String, void Function()> _pluginRegistrars = {
    'github': GitHubPlugin.register,
    'vercel': VercelPlugin.register,
    'supabase': SupabasePlugin.register,
    'termux': TermuxPlugin.register,
    'railway': RailwayPlugin.register,
    'netlify': NetlifyPlugin.register,
    'stripe': StripePlugin.register,
    'firebase': FirebasePlugin.register,
    'cloudflare': CloudflarePlugin.register,
  };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final installedPlugins = await getInstalledPlugins();
    for (final plugin in installedPlugins) {
      if (plugin.enabled && _pluginRegistrars.containsKey(plugin.id)) {
        _pluginRegistrars[plugin.id]!();
      }
    }
  }

  Future<List<Plugin>> getInstalledPlugins() async {
    final data = await _storage.read('installed_plugins');
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((j) => Plugin.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlugin(Plugin plugin) async {
    final plugins = await getInstalledPlugins();
    final index = plugins.indexWhere((p) => p.id == plugin.id);

    if (index != -1) {
      plugins[index] = plugin;
    } else {
      plugins.add(plugin);
    }

    await _storage.write(
      'installed_plugins',
      jsonEncode(plugins.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> uninstallPlugin(String pluginId) async {
    final plugins = await getInstalledPlugins();
    plugins.removeWhere((p) => p.id == pluginId);

    await _storage.write(
      'installed_plugins',
      jsonEncode(plugins.map((p) => p.toJson()).toList()),
    );

    _toolRegistry.unregisterPlugin(pluginId);
    _toolExecutor.unregisterExecutors(pluginId);
  }

  Future<void> togglePlugin(String pluginId, bool enabled) async {
    final plugins = await getInstalledPlugins();
    final index = plugins.indexWhere((p) => p.id == pluginId);

    if (index != -1) {
      plugins[index] = plugins[index].copyWith(enabled: enabled);
      await _storage.write(
        'installed_plugins',
        jsonEncode(plugins.map((p) => p.toJson()).toList()),
      );

      if (!enabled) {
        _toolRegistry.unregisterPlugin(pluginId);
        _toolExecutor.unregisterExecutors(pluginId);
      } else if (_pluginRegistrars.containsKey(pluginId)) {
        _pluginRegistrars[pluginId]!();
      }
    }
  }

  Future<void> updatePluginSettings(
      String pluginId, Map<String, dynamic> settings) async {
    final plugins = await getInstalledPlugins();
    final index = plugins.indexWhere((p) => p.id == pluginId);

    if (index != -1) {
      plugins[index] = plugins[index].copyWith(settings: settings);
      await _storage.write(
        'installed_plugins',
        jsonEncode(plugins.map((p) => p.toJson()).toList()),
      );
    }
  }

  Future<List<Tool>> getEnabledTools() async {
    final installedPlugins = await getInstalledPlugins();
    final enabledPluginIds =
        installedPlugins.where((p) => p.enabled).map((p) => p.id).toSet();

    return _toolRegistry
        .getAllTools()
        .where((t) => enabledPluginIds.contains(t.pluginId))
        .toList();
  }

  List<Tool> getToolsForPlugin(String pluginId) {
    return _toolRegistry.getToolsForPlugin(pluginId);
  }

  List<Tool> searchTools(String query) {
    return _toolRegistry.searchTools(query);
  }
}
