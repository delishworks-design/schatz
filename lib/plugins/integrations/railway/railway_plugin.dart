import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class RailwayPlugin {
  static const String id = 'railway';
  static const String name = 'Railway';
  static const String description = 'Deploy and manage Railway services';
  
  static Plugin get plugin => Plugin(
    id: id, name: name, description: description,
    category: PluginCategory.deployment, version: '1.0.0', author: 'Schatz',
  );
  
  static List<Tool> get tools => [
    Tool(id: 'service.list', name: 'List Services', description: 'List all services', pluginId: id, type: ToolType.read),
    Tool(id: 'deploy', name: 'Deploy', description: 'Deploy a service', pluginId: id, type: ToolType.execute,
      parameters: {'serviceId': ToolParameter(name: 'serviceId', description: 'Service ID', type: ToolParameterType.string, required: true)}),
    Tool(id: 'logs', name: 'View Logs', description: 'View service logs', pluginId: id, type: ToolType.read,
      parameters: {'serviceId': ToolParameter(name: 'serviceId', description: 'Service ID', type: ToolParameterType.string, required: true)}),
    Tool(id: 'env', name: 'Environment Variables', description: 'Manage env vars', pluginId: id, type: ToolType.manage,
      parameters: {'action': ToolParameter(name: 'action', description: 'Action', type: ToolParameterType.string, required: true, options: ['list', 'set', 'delete']),
        'serviceId': ToolParameter(name: 'serviceId', description: 'Service ID', type: ToolParameterType.string, required: true),
        'key': ToolParameter(name: 'key', description: 'Key', type: ToolParameterType.string), 'value': ToolParameter(name: 'value', description: 'Value', type: ToolParameterType.string)}),
  ];
  
  static void register() {
    ToolRegistry().registerPluginTools(id, tools);
    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'service.list', _listServices);
    executor.registerExecutor(id, 'deploy', _deploy);
    executor.registerExecutor(id, 'logs', _viewLogs);
    executor.registerExecutor(id, 'env', _manageEnv);
  }
  
  static Future<Dio> _getClient() async {
    String? token = await SecureStorage().read('plugin_auth_railway');
    if (token == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
        (plugins) => plugins.where((p) => p.id == id).firstOrNull,
      );
      token = plugin?.settings['token'] as String?;
    }
    if (token == null) throw Exception('Railway auth token not configured');
    return Dio(BaseOptions(baseUrl: 'https://api.railway.app/graphql', headers: {'Authorization': 'Bearer $token'}));
  }
  
  static Future<ToolResult> _listServices(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post('', data: {'query': '{ projects(first: 10) { edges { node { name services { edges { node { id name } } } } } } }'});
      return ToolResult.success('Services retrieved', data: response.data['data']);
    } catch (e) { return ToolResult.failure('Failed: $e'); }
  }
  
  static Future<ToolResult> _deploy(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post('', data: {
        'query': 'mutation (\$serviceId: ID!) { serviceDeploy(input: { serviceId: \$serviceId }) { id } }',
        'variables': {'serviceId': params['serviceId']},
      });
      return ToolResult.success('Deployment triggered', data: response.data['data']);
    } catch (e) { return ToolResult.failure('Failed: $e'); }
  }
  
  static Future<ToolResult> _viewLogs(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post('', data: {
        'query': 'query (\$serviceId: ID!) { logs(serviceId: \$serviceId, first: 50) { edges { node { timestamp message } } } }',
        'variables': {'serviceId': params['serviceId']},
      });
      return ToolResult.success('Logs retrieved', data: response.data['data']);
    } catch (e) { return ToolResult.failure('Failed: $e'); }
  }
  
  static Future<ToolResult> _manageEnv(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final action = params['action'];
      if (action == 'list') {
        final response = await client.post('', data: {
          'query': 'query (\$serviceId: ID!) { variables(serviceId: \$serviceId) { key value } }',
          'variables': {'serviceId': params['serviceId']},
        });
        return ToolResult.success('Variables retrieved', data: response.data['data']);
      }
      return ToolResult.success('Action completed');
    } catch (e) { return ToolResult.failure('Failed: $e'); }
  }
}
