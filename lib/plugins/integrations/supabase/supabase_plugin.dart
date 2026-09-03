import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class SupabasePlugin {
  static const String id = 'supabase';
  static const String name = 'Supabase';
  static const String description = 'Interact with Supabase databases and auth';

  static Plugin get plugin => Plugin(
        id: id,
        name: name,
        description: description,
        category: PluginCategory.database,
        version: '1.0.0',
        author: 'Schatz',
        requiredPermissions: ['database', 'auth'],
      );

  static List<Tool> get tools => [
        Tool(
          id: 'query',
          name: 'Run SQL Query',
          description: 'Execute a SQL query',
          pluginId: id,
          type: ToolType.execute,
          parameters: {
            'sql': ToolParameter(
                name: 'sql',
                description: 'SQL query',
                type: ToolParameterType.string,
                required: true),
          },
        ),
        Tool(
          id: 'table.list',
          name: 'List Tables',
          description: 'List all tables in the database',
          pluginId: id,
          type: ToolType.read,
        ),
        Tool(
          id: 'row.select',
          name: 'Select Rows',
          description: 'Select rows from a table',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'table': ToolParameter(
                name: 'table',
                description: 'Table name',
                type: ToolParameterType.string,
                required: true),
            'columns': ToolParameter(
                name: 'columns',
                description: 'Columns to select',
                type: ToolParameterType.list),
            'filters': ToolParameter(
                name: 'filters',
                description: 'Filter conditions',
                type: ToolParameterType.map),
            'limit': ToolParameter(
                name: 'limit',
                description: 'Limit results',
                type: ToolParameterType.int),
          },
        ),
        Tool(
          id: 'row.insert',
          name: 'Insert Row',
          description: 'Insert a new row',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'table': ToolParameter(
                name: 'table',
                description: 'Table name',
                type: ToolParameterType.string,
                required: true),
            'data': ToolParameter(
                name: 'data',
                description: 'Row data',
                type: ToolParameterType.map,
                required: true),
          },
        ),
        Tool(
          id: 'row.update',
          name: 'Update Rows',
          description: 'Update rows in a table',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'table': ToolParameter(
                name: 'table',
                description: 'Table name',
                type: ToolParameterType.string,
                required: true),
            'data': ToolParameter(
                name: 'data',
                description: 'Data to update',
                type: ToolParameterType.map,
                required: true),
            'filters': ToolParameter(
                name: 'filters',
                description: 'Filter conditions',
                type: ToolParameterType.map,
                required: true),
          },
        ),
        Tool(
          id: 'row.delete',
          name: 'Delete Rows',
          description: 'Delete rows from a table',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'table': ToolParameter(
                name: 'table',
                description: 'Table name',
                type: ToolParameterType.string,
                required: true),
            'filters': ToolParameter(
                name: 'filters',
                description: 'Filter conditions',
                type: ToolParameterType.map,
                required: true),
          },
        ),
        Tool(
          id: 'auth.signup',
          name: 'Sign Up',
          description: 'Create a new user',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'email': ToolParameter(
                name: 'email',
                description: 'Email',
                type: ToolParameterType.string,
                required: true),
            'password': ToolParameter(
                name: 'password',
                description: 'Password',
                type: ToolParameterType.string,
                required: true),
          },
        ),
        Tool(
          id: 'auth.signin',
          name: 'Sign In',
          description: 'Sign in a user',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'email': ToolParameter(
                name: 'email',
                description: 'Email',
                type: ToolParameterType.string,
                required: true),
            'password': ToolParameter(
                name: 'password',
                description: 'Password',
                type: ToolParameterType.string,
                required: true),
          },
        ),
      ];

  static void register() {
    final registry = ToolRegistry();
    registry.registerPluginTools(id, tools);

    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'query', _runQuery);
    executor.registerExecutor(id, 'table.list', _listTables);
    executor.registerExecutor(id, 'row.select', _selectRows);
    executor.registerExecutor(id, 'row.insert', _insertRow);
    executor.registerExecutor(id, 'row.update', _updateRows);
    executor.registerExecutor(id, 'row.delete', _deleteRows);
    executor.registerExecutor(id, 'auth.signup', _signUp);
    executor.registerExecutor(id, 'auth.signin', _signIn);
  }

  static Future<Dio> _getClient() async {
    final storage = SecureStorage();
    final config = await _getConfig();

    return Dio(BaseOptions(
      baseUrl: '${config['url']}/rest/v1',
      headers: {
        'apikey': config['apiKey'],
        'Authorization': 'Bearer ${config['apiKey']}',
        'Content-Type': 'application/json',
      },
    ));
  }

  static Future<Map<String, String>> _getConfig() async {
    String? url = await SecureStorage().read('plugin_supabase_url');
    String? apiKey = await SecureStorage().read('plugin_supabase_key');
    if (url == null || apiKey == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
            (plugins) => plugins.where((p) => p.id == id).firstOrNull,
          );
      url ??= plugin?.settings['url'] as String?;
      apiKey ??= plugin?.settings['anon_key'] as String?;
    }
    if (url == null || apiKey == null) {
      throw Exception('Supabase credentials not configured');
    }
    return {'url': url, 'apiKey': apiKey};
  }

  static Future<ToolResult> _runQuery(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response =
          await client.post('/rpc/run_query', data: {'query': params['sql']});

      return ToolResult.success(
        'Query executed successfully',
        data: {'result': response.data},
      );
    } catch (e) {
      return ToolResult.failure('Failed to run query: $e');
    }
  }

  static Future<ToolResult> _listTables(Map<String, dynamic> params) async {
    try {
      final config = await _getConfig();
      final client = Dio(BaseOptions(
        baseUrl: '${config['url']}/rest/v1',
        headers: {
          'apikey': config['apiKey'],
          'Authorization': 'Bearer ${config['apiKey']}',
        },
      ));

      final response = await client.get('/', queryParameters: {'select': '*'});

      return ToolResult.success(
        'Tables retrieved',
        data: {'tables': response.data},
      );
    } catch (e) {
      return ToolResult.failure('Failed to list tables: $e');
    }
  }

  static Future<ToolResult> _selectRows(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final table = params['table'];
      final columns = params['columns']?.join(',') ?? '*';
      final limit = params['limit'] ?? 10;

      final queryParams = <String, dynamic>{
        'select': columns,
        'limit': limit,
      };

      if (params['filters'] is Map) {
        params['filters'].forEach((key, value) {
          queryParams['${key}_eq'] = value;
        });
      }

      final response =
          await client.get('/$table', queryParameters: queryParams);

      return ToolResult.success(
        'Found ${response.data.length} rows',
        data: {'rows': response.data},
      );
    } catch (e) {
      return ToolResult.failure('Failed to select rows: $e');
    }
  }

  static Future<ToolResult> _insertRow(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post(
        '/${params['table']}',
        data: params['data'],
        options: Options(headers: {'Prefer': 'return=representation'}),
      );

      return ToolResult.success(
        'Row inserted successfully',
        data: {'row': response.data},
      );
    } catch (e) {
      return ToolResult.failure('Failed to insert row: $e');
    }
  }

  static Future<ToolResult> _updateRows(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final queryParams = <String, dynamic>{};

      if (params['filters'] is Map) {
        params['filters'].forEach((key, value) {
          queryParams['${key}_eq'] = value;
        });
      }

      final response = await client.patch(
        '/${params['table']}',
        data: params['data'],
        queryParameters: queryParams,
        options: Options(headers: {'Prefer': 'return=representation'}),
      );

      return ToolResult.success(
        'Rows updated successfully',
        data: {'updated': response.data},
      );
    } catch (e) {
      return ToolResult.failure('Failed to update rows: $e');
    }
  }

  static Future<ToolResult> _deleteRows(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final queryParams = <String, dynamic>{};

      if (params['filters'] is Map) {
        params['filters'].forEach((key, value) {
          queryParams['${key}_eq'] = value;
        });
      }

      await client.delete(
        '/${params['table']}',
        queryParameters: queryParams,
      );

      return ToolResult.success('Rows deleted successfully');
    } catch (e) {
      return ToolResult.failure('Failed to delete rows: $e');
    }
  }

  static Future<ToolResult> _signUp(Map<String, dynamic> params) async {
    try {
      final config = await _getConfig();
      final client = Dio(BaseOptions(
        baseUrl: '${config['url']}/auth/v1',
        headers: {
          'apikey': config['apiKey'],
          'Content-Type': 'application/json',
        },
      ));

      final response = await client.post('/signup', data: {
        'email': params['email'],
        'password': params['password'],
      });

      return ToolResult.success(
        'User signed up successfully',
        data: {'user': response.data['user']},
      );
    } catch (e) {
      return ToolResult.failure('Failed to sign up: $e');
    }
  }

  static Future<ToolResult> _signIn(Map<String, dynamic> params) async {
    try {
      final config = await _getConfig();
      final client = Dio(BaseOptions(
        baseUrl: '${config['url']}/auth/v1',
        headers: {
          'apikey': config['apiKey'],
          'Content-Type': 'application/json',
        },
      ));

      final response = await client.post('/token?grant_type=password', data: {
        'email': params['email'],
        'password': params['password'],
      });

      return ToolResult.success(
        'User signed in successfully',
        data: {'access_token': response.data['access_token']},
      );
    } catch (e) {
      return ToolResult.failure('Failed to sign in: $e');
    }
  }
}
