import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class VercelPlugin {
  static const String id = 'vercel';
  static const String name = 'Vercel';
  static const String description = 'Deploy and manage Vercel projects';

  static Plugin get plugin => Plugin(
        id: id,
        name: name,
        description: description,
        category: PluginCategory.deployment,
        version: '1.0.0',
        author: 'Schatz',
        requiredPermissions: ['deploy', 'read'],
      );

  static List<Tool> get tools => [
        Tool(
          id: 'list',
          name: 'List Projects',
          description: 'List all Vercel projects',
          pluginId: id,
          type: ToolType.read,
        ),
        Tool(
          id: 'deploy',
          name: 'Deploy',
          description: 'Deploy a project to Vercel',
          pluginId: id,
          type: ToolType.execute,
          parameters: {
            'name': ToolParameter(
                name: 'name',
                description: 'Project name',
                type: ToolParameterType.string,
                required: true),
            'framework': ToolParameter(
                name: 'framework',
                description: 'Framework',
                type: ToolParameterType.string),
            'files': ToolParameter(
                name: 'files',
                description: 'Files to deploy',
                type: ToolParameterType.map),
          },
        ),
        Tool(
          id: 'logs',
          name: 'View Logs',
          description: 'View deployment logs',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'deploymentId': ToolParameter(
                name: 'deploymentId',
                description: 'Deployment ID',
                type: ToolParameterType.string,
                required: true),
          },
        ),
        Tool(
          id: 'domain.manage',
          name: 'Manage Domains',
          description: 'Add or remove domains',
          pluginId: id,
          type: ToolType.manage,
          parameters: {
            'action': ToolParameter(
                name: 'action',
                description: 'Action',
                type: ToolParameterType.string,
                required: true,
                options: ['add', 'remove', 'list']),
            'domain': ToolParameter(
                name: 'domain',
                description: 'Domain name',
                type: ToolParameterType.string),
          },
        ),
        Tool(
          id: 'env.manage',
          name: 'Manage Environment Variables',
          description: 'Add, update, or remove env vars',
          pluginId: id,
          type: ToolType.manage,
          parameters: {
            'action': ToolParameter(
                name: 'action',
                description: 'Action',
                type: ToolParameterType.string,
                required: true,
                options: ['add', 'update', 'remove', 'list']),
            'projectId': ToolParameter(
                name: 'projectId',
                description: 'Project ID',
                type: ToolParameterType.string,
                required: true),
            'key': ToolParameter(
                name: 'key',
                description: 'Variable key',
                type: ToolParameterType.string),
            'value': ToolParameter(
                name: 'value',
                description: 'Variable value',
                type: ToolParameterType.string),
          },
        ),
      ];

  static void register() {
    final registry = ToolRegistry();
    registry.registerPluginTools(id, tools);

    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'list', _listProjects);
    executor.registerExecutor(id, 'deploy', _deploy);
    executor.registerExecutor(id, 'logs', _viewLogs);
    executor.registerExecutor(id, 'domain.manage', _manageDomains);
    executor.registerExecutor(id, 'env.manage', _manageEnvVars);
  }

  static Future<Dio> _getClient() async {
    String? token = await SecureStorage().read('plugin_auth_vercel');
    if (token == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
            (plugins) => plugins.where((p) => p.id == id).firstOrNull,
          );
      token = plugin?.settings['token'] as String?;
    }
    if (token == null) throw Exception('Vercel auth token not configured');

    return Dio(BaseOptions(
      baseUrl: 'https://api.vercel.com',
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  static Future<ToolResult> _listProjects(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.get('/v9/projects');

      final projects = (response.data['projects'] as List)
          .take(10)
          .map((p) => {
                'id': p['id'],
                'name': p['name'],
                'framework': p['framework'],
                'latestDeployment': p['latestDeployments']?.isNotEmpty == true
                    ? p['latestDeployments'][0]['createdAt']
                    : null,
              })
          .toList();

      return ToolResult.success(
        'Found ${response.data['projects'].length} projects',
        data: {'projects': projects},
      );
    } catch (e) {
      return ToolResult.failure('Failed to list projects: $e');
    }
  }

  static Future<ToolResult> _deploy(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post('/v13/deployments', data: {
        'name': params['name'],
        if (params['framework'] != null) 'framework': params['framework'],
      });

      return ToolResult.success(
        'Deployment created: ${response.data['url']}',
        data: response.data,
      );
    } catch (e) {
      return ToolResult.failure('Failed to deploy: $e');
    }
  }

  static Future<ToolResult> _viewLogs(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response =
          await client.get('/v2/deployments/${params['deploymentId']}/events');

      return ToolResult.success(
        'Logs retrieved',
        data: {'logs': response.data},
      );
    } catch (e) {
      return ToolResult.failure('Failed to view logs: $e');
    }
  }

  static Future<ToolResult> _manageDomains(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final action = params['action'];

      switch (action) {
        case 'list':
          final response = await client.get('/v5/domains');
          return ToolResult.success(
            'Found ${response.data['domains'].length} domains',
            data: {'domains': response.data['domains']},
          );
        case 'add':
          final response = await client
              .post('/v5/domains', data: {'name': params['domain']});
          return ToolResult.success('Domain added: ${response.data['name']}');
        case 'remove':
          await client.delete('/v5/domains/${params['domain']}');
          return ToolResult.success('Domain removed: ${params['domain']}');
        default:
          return ToolResult.failure('Unknown action: $action');
      }
    } catch (e) {
      return ToolResult.failure('Failed to manage domains: $e');
    }
  }

  static Future<ToolResult> _manageEnvVars(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final action = params['action'];

      switch (action) {
        case 'list':
          final response =
              await client.get('/v9/projects/${params['projectId']}/env');
          return ToolResult.success(
            'Found ${response.data['envs'].length} variables',
            data: {'envVars': response.data['envs']},
          );
        case 'add':
          final response = await client
              .post('/v9/projects/${params['projectId']}/env', data: {
            'key': params['key'],
            'value': params['value'],
            'type': 'encrypted',
          });
          return ToolResult.success(
              'Environment variable added: ${params['key']}');
        case 'remove':
          await client.delete(
              '/v9/projects/${params['projectId']}/env/${params['key']}');
          return ToolResult.success(
              'Environment variable removed: ${params['key']}');
        default:
          return ToolResult.failure('Unknown action: $action');
      }
    } catch (e) {
      return ToolResult.failure('Failed to manage env vars: $e');
    }
  }
}
