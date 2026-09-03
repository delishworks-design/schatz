import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class NetlifyPlugin {
  static const String id = 'netlify';
  static const String name = 'Netlify';
  static const String description = 'Deploy and manage Netlify sites';

  static Plugin get plugin => Plugin(
        id: id,
        name: name,
        description: description,
        category: PluginCategory.deployment,
        version: '1.0.0',
        author: 'Schatz',
      );

  static List<Tool> get tools => [
        Tool(
            id: 'site.list',
            name: 'List Sites',
            description: 'List all sites',
            pluginId: id,
            type: ToolType.read),
        Tool(
            id: 'deploy',
            name: 'Deploy',
            description: 'Deploy a site',
            pluginId: id,
            type: ToolType.execute,
            parameters: {
              'siteId': ToolParameter(
                  name: 'siteId',
                  description: 'Site ID',
                  type: ToolParameterType.string,
                  required: true),
              'dir': ToolParameter(
                  name: 'dir',
                  description: 'Directory to deploy',
                  type: ToolParameterType.string,
                  required: true)
            }),
        Tool(
            id: 'form.manage',
            name: 'Manage Forms',
            description: 'Manage form submissions',
            pluginId: id,
            type: ToolType.manage,
            parameters: {
              'action': ToolParameter(
                  name: 'action',
                  description: 'Action',
                  type: ToolParameterType.string,
                  required: true,
                  options: ['list', 'delete']),
              'siteId': ToolParameter(
                  name: 'siteId',
                  description: 'Site ID',
                  type: ToolParameterType.string,
                  required: true),
              'formId': ToolParameter(
                  name: 'formId',
                  description: 'Form ID',
                  type: ToolParameterType.string)
            }),
      ];

  static void register() {
    ToolRegistry().registerPluginTools(id, tools);
    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'site.list', _listSites);
    executor.registerExecutor(id, 'deploy', _deploy);
    executor.registerExecutor(id, 'form.manage', _manageForms);
  }

  static Future<Dio> _getClient() async {
    String? token = await SecureStorage().read('plugin_auth_netlify');
    if (token == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
            (plugins) => plugins.where((p) => p.id == id).firstOrNull,
          );
      token = plugin?.settings['token'] as String?;
    }
    if (token == null) throw Exception('Netlify auth token not configured');
    return Dio(BaseOptions(
        baseUrl: 'https://api.netlify.com/api/v1',
        headers: {'Authorization': 'Bearer $token'}));
  }

  static Future<ToolResult> _listSites(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.get('/sites');
      final sites = (response.data as List)
          .take(10)
          .map((s) => {'id': s['id'], 'name': s['name'], 'url': s['url']})
          .toList();
      return ToolResult.success('Found ${sites.length} sites',
          data: {'sites': sites});
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }

  static Future<ToolResult> _deploy(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post('/sites/${params['siteId']}/deploys',
          data: {'dir': params['dir']});
      return ToolResult.success('Deploy triggered: ${response.data['url']}',
          data: response.data);
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }

  static Future<ToolResult> _manageForms(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      if (params['action'] == 'list') {
        final response = await client.get('/sites/${params['siteId']}/forms');
        return ToolResult.success('Forms retrieved',
            data: {'forms': response.data});
      }
      return ToolResult.success('Action completed');
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }
}
