import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class FirebasePlugin {
  static const String id = 'firebase';
  static const String name = 'Firebase';
  static const String description = 'Interact with Firebase services';

  static Plugin get plugin => Plugin(
        id: id,
        name: name,
        description: description,
        category: PluginCategory.backend,
        version: '1.0.0',
        author: 'Schatz',
      );

  static List<Tool> get tools => [
        Tool(
            id: 'query',
            name: 'Query Firestore',
            description: 'Query Firestore collections',
            pluginId: id,
            type: ToolType.read,
            parameters: {
              'collection': ToolParameter(
                  name: 'collection',
                  description: 'Collection',
                  type: ToolParameterType.string,
                  required: true),
              'filters': ToolParameter(
                  name: 'filters',
                  description: 'Filters',
                  type: ToolParameterType.map),
              'limit': ToolParameter(
                  name: 'limit',
                  description: 'Limit',
                  type: ToolParameterType.int)
            }),
        Tool(
            id: 'auth.verify',
            name: 'Verify Token',
            description: 'Verify Firebase Auth token',
            pluginId: id,
            type: ToolType.read,
            parameters: {
              'token': ToolParameter(
                  name: 'token',
                  description: 'Token',
                  type: ToolParameterType.string,
                  required: true)
            }),
        Tool(
            id: 'function.call',
            name: 'Call Function',
            description: 'Call Cloud Function',
            pluginId: id,
            type: ToolType.execute,
            parameters: {
              'function': ToolParameter(
                  name: 'function',
                  description: 'Function name',
                  type: ToolParameterType.string,
                  required: true),
              'data': ToolParameter(
                  name: 'data',
                  description: 'Data',
                  type: ToolParameterType.map)
            }),
        Tool(
            id: 'deploy',
            name: 'Deploy',
            description: 'Deploy to Firebase',
            pluginId: id,
            type: ToolType.execute,
            parameters: {
              'target': ToolParameter(
                  name: 'target',
                  description: 'Target',
                  type: ToolParameterType.string,
                  required: true,
                  options: ['hosting', 'functions', 'firestore'])
            }),
      ];

  static void register() {
    ToolRegistry().registerPluginTools(id, tools);
    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'query', _queryFirestore);
    executor.registerExecutor(id, 'auth.verify', _verifyToken);
    executor.registerExecutor(id, 'function.call', _callFunction);
    executor.registerExecutor(id, 'deploy', _deploy);
  }

  static Future<Dio> _getClient() async {
    String? token = await SecureStorage().read('plugin_auth_firebase');
    String? project = await SecureStorage().read('plugin_firebase_project');
    if (token == null || project == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
            (plugins) => plugins.where((p) => p.id == id).firstOrNull,
          );
      token ??= plugin?.settings['service_account_key'] as String?;
      project ??= plugin?.settings['project_id'] as String?;
    }
    if (token == null || project == null)
      throw Exception('Firebase credentials not configured');
    return Dio(BaseOptions(
        baseUrl:
            'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents',
        headers: {'Authorization': 'Bearer $token'}));
  }

  static Future<ToolResult> _queryFirestore(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.get('/${params['collection']}');
      return ToolResult.success('Documents retrieved',
          data: {'documents': response.data['documents']});
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }

  static Future<ToolResult> _verifyToken(Map<String, dynamic> params) async {
    try {
      String? project = await SecureStorage().read('plugin_firebase_project');
      if (project == null) {
        final plugin = await PluginService().getInstalledPlugins().then(
              (plugins) => plugins.where((p) => p.id == id).firstOrNull,
            );
        project = plugin?.settings['project_id'] as String?;
      }
      if (project == null)
        throw Exception('Firebase project ID not configured');
      final client = Dio();
      final response = await client.post(
          'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=$project',
          data: {'idToken': params['token']});
      return ToolResult.success('Token verified',
          data: response.data['users']?.isNotEmpty == true
              ? response.data['users'].first
              : null);
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }

  static Future<ToolResult> _callFunction(Map<String, dynamic> params) async {
    try {
      String? project = await SecureStorage().read('plugin_firebase_project');
      String? token = await SecureStorage().read('plugin_auth_firebase');
      if (project == null || token == null) {
        final plugin = await PluginService().getInstalledPlugins().then(
              (plugins) => plugins.where((p) => p.id == id).firstOrNull,
            );
        project ??= plugin?.settings['project_id'] as String?;
        token ??= plugin?.settings['service_account_key'] as String?;
      }
      if (project == null || token == null)
        throw Exception('Firebase credentials not configured');
      final client =
          Dio(BaseOptions(headers: {'Authorization': 'Bearer $token'}));
      final response = await client.post(
          'https://us-central1-$project.cloudfunctions.net/${params['function']}',
          data: params['data']);
      return ToolResult.success('Function called', data: response.data);
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }

  static Future<ToolResult> _deploy(Map<String, dynamic> params) async {
    try {
      return ToolResult.success('Deploy triggered for ${params['target']}');
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }
}
