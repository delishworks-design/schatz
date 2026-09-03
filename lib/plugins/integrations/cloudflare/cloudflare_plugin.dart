import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class CloudflarePlugin {
  static const String id = 'cloudflare';
  static const String name = 'Cloudflare';
  static const String description = 'Manage Cloudflare DNS, Workers, and KV';
  
  static Plugin get plugin => Plugin(
    id: id, name: name, description: description,
    category: PluginCategory.infrastructure, version: '1.0.0', author: 'Schatz',
  );
  
  static List<Tool> get tools => [
    Tool(id: 'dns.manage', name: 'Manage DNS', description: 'Manage DNS records', pluginId: id, type: ToolType.manage,
      parameters: {'action': ToolParameter(name: 'action', description: 'Action', type: ToolParameterType.string, required: true, options: ['list', 'create', 'delete']),
        'zoneId': ToolParameter(name: 'zoneId', description: 'Zone ID', type: ToolParameterType.string, required: true),
        'record': ToolParameter(name: 'record', description: 'Record data', type: ToolParameterType.map),
        'recordId': ToolParameter(name: 'recordId', description: 'Record ID', type: ToolParameterType.string)}),
    Tool(id: 'worker.deploy', name: 'Deploy Worker', description: 'Deploy a Worker script', pluginId: id, type: ToolType.execute,
      parameters: {'script': ToolParameter(name: 'script', description: 'Script name', type: ToolParameterType.string, required: true),
        'content': ToolParameter(name: 'content', description: 'Script content', type: ToolParameterType.string, required: true),
        'accountId': ToolParameter(name: 'accountId', description: 'Account ID', type: ToolParameterType.string, required: true)}),
    Tool(id: 'kv.manage', name: 'Manage KV', description: 'Manage KV namespace', pluginId: id, type: ToolType.manage,
      parameters: {'action': ToolParameter(name: 'action', description: 'Action', type: ToolParameterType.string, required: true, options: ['get', 'put', 'delete', 'list']),
        'namespaceId': ToolParameter(name: 'namespaceId', description: 'Namespace ID', type: ToolParameterType.string, required: true),
        'key': ToolParameter(name: 'key', description: 'Key', type: ToolParameterType.string), 'value': ToolParameter(name: 'value', description: 'Value', type: ToolParameterType.string),
        'accountId': ToolParameter(name: 'accountId', description: 'Account ID', type: ToolParameterType.string, required: true)}),
  ];
  
  static void register() {
    ToolRegistry().registerPluginTools(id, tools);
    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'dns.manage', _manageDns);
    executor.registerExecutor(id, 'worker.deploy', _deployWorker);
    executor.registerExecutor(id, 'kv.manage', _manageKv);
  }
  
  static Future<Dio> _getClient() async {
    String? token = await SecureStorage().read('plugin_auth_cloudflare');
    if (token == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
        (plugins) => plugins.where((p) => p.id == id).firstOrNull,
      );
      token = plugin?.settings['api_token'] as String?;
    }
    if (token == null) throw Exception('Cloudflare auth token not configured');
    return Dio(BaseOptions(baseUrl: 'https://api.cloudflare.com/client/v4', headers: {'Authorization': 'Bearer $token'}));
  }
  
  static Future<ToolResult> _manageDns(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final action = params['action'];
      final zoneId = params['zoneId'];
      
      switch (action) {
        case 'list':
          final response = await client.get('/zones/$zoneId/dns_records');
          return ToolResult.success('DNS records retrieved', data: {'records': response.data['result']});
        case 'create':
          final response = await client.post('/zones/$zoneId/dns_records', data: params['record']);
          return ToolResult.success('DNS record created', data: response.data['result']);
        case 'delete':
          await client.delete('/zones/$zoneId/dns_records/${params['recordId']}');
          return ToolResult.success('DNS record deleted');
        default:
          return ToolResult.failure('Unknown action');
      }
    } catch (e) { return ToolResult.failure('Failed: $e'); }
  }
  
  static Future<ToolResult> _deployWorker(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final accountId = params['accountId'];
      final response = await client.put(
        '/accounts/$accountId/workers/scripts/${params['script']}',
        data: params['content'],
        options: Options(headers: {'Content-Type': 'application/javascript'}),
      );
      return ToolResult.success('Worker deployed: ${params['script']}', data: response.data);
    } catch (e) { return ToolResult.failure('Failed: $e'); }
  }
  
  static Future<ToolResult> _manageKv(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final accountId = params['accountId'];
      final nsId = params['namespaceId'];
      final action = params['action'];
      
      switch (action) {
        case 'get':
          final response = await client.get('/accounts/$accountId/kv/namespaces/$nsId/values/${params['key']}');
          return ToolResult.success('Value retrieved', data: {'value': response.data});
        case 'put':
          await client.put('/accounts/$accountId/kv/namespaces/$nsId/values/${params['key']}', data: params['value']);
          return ToolResult.success('Value stored');
        case 'delete':
          await client.delete('/accounts/$accountId/kv/namespaces/$nsId/values/${params['key']}');
          return ToolResult.success('Value deleted');
        case 'list':
          final response = await client.get('/accounts/$accountId/kv/namespaces/$nsId/keys');
          return ToolResult.success('Keys retrieved', data: {'keys': response.data['result']});
        default:
          return ToolResult.failure('Unknown action');
      }
    } catch (e) { return ToolResult.failure('Failed: $e'); }
  }
}
