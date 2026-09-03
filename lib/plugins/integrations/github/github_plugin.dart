import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class GitHubPlugin {
  static const String id = 'github';
  static const String name = 'GitHub';
  static const String description =
      'Interact with GitHub repositories, issues, and pull requests';

  static Plugin get plugin => Plugin(
        id: id,
        name: name,
        description: description,
        category: PluginCategory.development,
        version: '1.0.0',
        author: 'Schatz',
        requiredPermissions: ['repo', 'read:org', 'user'],
      );

  static List<Tool> get tools => [
        Tool(
          id: 'read',
          name: 'Read Repository',
          description: 'Read repository details, files, or content',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'owner': ToolParameter(
                name: 'owner',
                description: 'Repository owner',
                type: ToolParameterType.string,
                required: true),
            'repo': ToolParameter(
                name: 'repo',
                description: 'Repository name',
                type: ToolParameterType.string,
                required: true),
            'path': ToolParameter(
                name: 'path',
                description: 'File path (optional)',
                type: ToolParameterType.string),
          },
        ),
        Tool(
          id: 'search',
          name: 'Search Code',
          description: 'Search code across repositories',
          pluginId: id,
          type: ToolType.search,
          parameters: {
            'query': ToolParameter(
                name: 'query',
                description: 'Search query',
                type: ToolParameterType.string,
                required: true),
            'repo': ToolParameter(
                name: 'repo',
                description: 'Limit to repo (owner/repo)',
                type: ToolParameterType.string),
          },
        ),
        Tool(
          id: 'issue.list',
          name: 'List Issues',
          description: 'List issues in a repository',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'owner': ToolParameter(
                name: 'owner',
                description: 'Repository owner',
                type: ToolParameterType.string,
                required: true),
            'repo': ToolParameter(
                name: 'repo',
                description: 'Repository name',
                type: ToolParameterType.string,
                required: true),
            'state': ToolParameter(
                name: 'state',
                description: 'Issue state',
                type: ToolParameterType.string,
                options: ['open', 'closed', 'all']),
          },
        ),
        Tool(
          id: 'issue.create',
          name: 'Create Issue',
          description: 'Create a new issue',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'owner': ToolParameter(
                name: 'owner',
                description: 'Repository owner',
                type: ToolParameterType.string,
                required: true),
            'repo': ToolParameter(
                name: 'repo',
                description: 'Repository name',
                type: ToolParameterType.string,
                required: true),
            'title': ToolParameter(
                name: 'title',
                description: 'Issue title',
                type: ToolParameterType.string,
                required: true),
            'body': ToolParameter(
                name: 'body',
                description: 'Issue body',
                type: ToolParameterType.string),
            'labels': ToolParameter(
                name: 'labels',
                description: 'Labels',
                type: ToolParameterType.list),
          },
        ),
        Tool(
          id: 'pr.list',
          name: 'List Pull Requests',
          description: 'List pull requests',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'owner': ToolParameter(
                name: 'owner',
                description: 'Repository owner',
                type: ToolParameterType.string,
                required: true),
            'repo': ToolParameter(
                name: 'repo',
                description: 'Repository name',
                type: ToolParameterType.string,
                required: true),
            'state': ToolParameter(
                name: 'state',
                description: 'PR state',
                type: ToolParameterType.string,
                options: ['open', 'closed', 'all']),
          },
        ),
        Tool(
          id: 'pr.create',
          name: 'Create Pull Request',
          description: 'Create a new pull request',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'owner': ToolParameter(
                name: 'owner',
                description: 'Repository owner',
                type: ToolParameterType.string,
                required: true),
            'repo': ToolParameter(
                name: 'repo',
                description: 'Repository name',
                type: ToolParameterType.string,
                required: true),
            'title': ToolParameter(
                name: 'title',
                description: 'PR title',
                type: ToolParameterType.string,
                required: true),
            'head': ToolParameter(
                name: 'head',
                description: 'Head branch',
                type: ToolParameterType.string,
                required: true),
            'base': ToolParameter(
                name: 'base',
                description: 'Base branch',
                type: ToolParameterType.string,
                required: true),
            'body': ToolParameter(
                name: 'body',
                description: 'PR body',
                type: ToolParameterType.string),
          },
        ),
        Tool(
          id: 'deploy',
          name: 'Trigger Deployment',
          description: 'Trigger GitHub Actions deployment',
          pluginId: id,
          type: ToolType.execute,
          parameters: {
            'owner': ToolParameter(
                name: 'owner',
                description: 'Repository owner',
                type: ToolParameterType.string,
                required: true),
            'repo': ToolParameter(
                name: 'repo',
                description: 'Repository name',
                type: ToolParameterType.string,
                required: true),
            'workflow': ToolParameter(
                name: 'workflow',
                description: 'Workflow file name',
                type: ToolParameterType.string,
                required: true),
            'ref': ToolParameter(
                name: 'ref',
                description: 'Branch or tag',
                type: ToolParameterType.string),
          },
        ),
      ];

  static void register() {
    final registry = ToolRegistry();
    registry.registerPluginTools(id, tools);

    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'read', _readRepo);
    executor.registerExecutor(id, 'search', _searchCode);
    executor.registerExecutor(id, 'issue.list', _listIssues);
    executor.registerExecutor(id, 'issue.create', _createIssue);
    executor.registerExecutor(id, 'pr.list', _listPrs);
    executor.registerExecutor(id, 'pr.create', _createPr);
    executor.registerExecutor(id, 'deploy', _deploy);
  }

  static Future<Dio> _getClient() async {
    String? token = await SecureStorage().read('plugin_auth_github');
    if (token == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
            (plugins) => plugins.where((p) => p.id == id).firstOrNull,
          );
      token = plugin?.settings['token'] as String?;
    }
    if (token == null) throw Exception('GitHub auth token not configured');

    return Dio(BaseOptions(
      baseUrl: 'https://api.github.com',
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    ));
  }

  static Future<ToolResult> _readRepo(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response =
          await client.get('/repos/${params['owner']}/${params['repo']}');
      final data = response.data;

      return ToolResult.success(
        'Repository: ${data['full_name']}\n'
        'Description: ${data['description'] ?? 'No description'}\n'
        'Stars: ${data['stargazers_count']}\n'
        'Language: ${data['language'] ?? 'N/A'}',
        data: data,
      );
    } catch (e) {
      return ToolResult.failure('Failed to read repository: $e');
    }
  }

  static Future<ToolResult> _searchCode(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final query = params['repo'] != null
          ? '${params['query']} repo:${params['repo']}'
          : params['query'];

      final response =
          await client.get('/search/code', queryParameters: {'q': query});
      final items = (response.data['items'] as List?)?.take(5).toList() ?? [];

      final results = items
          .map((item) => {
                'name': item['name'],
                'path': item['path'],
                'repository': item['repository']?['full_name'],
              })
          .toList();

      return ToolResult.success(
        'Found ${response.data['total_count']} results, showing top ${results.length}',
        data: {'results': results, 'total': response.data['total_count']},
      );
    } catch (e) {
      return ToolResult.failure('Failed to search code: $e');
    }
  }

  static Future<ToolResult> _listIssues(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.get(
        '/repos/${params['owner']}/${params['repo']}/issues',
        queryParameters: {'state': params['state'] ?? 'open'},
      );

      final issues = (response.data as List?)
              ?.take(10)
              .map((issue) => {
                    'number': issue['number'],
                    'title': issue['title'],
                    'state': issue['state'],
                    'user': issue['user']?['login'],
                  })
              .toList() ??
          [];

      return ToolResult.success(
        'Found ${response.data.length} issues',
        data: {'issues': issues},
      );
    } catch (e) {
      return ToolResult.failure('Failed to list issues: $e');
    }
  }

  static Future<ToolResult> _createIssue(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post(
        '/repos/${params['owner']}/${params['repo']}/issues',
        data: {
          'title': params['title'],
          if (params['body'] != null) 'body': params['body'],
          if (params['labels'] != null) 'labels': params['labels'],
        },
      );

      return ToolResult.success(
        'Created issue #${response.data['number']}: ${response.data['title']}',
        data: response.data,
      );
    } catch (e) {
      return ToolResult.failure('Failed to create issue: $e');
    }
  }

  static Future<ToolResult> _listPrs(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.get(
        '/repos/${params['owner']}/${params['repo']}/pulls',
        queryParameters: {'state': params['state'] ?? 'open'},
      );

      final prs = (response.data as List?)
              ?.take(10)
              .map((pr) => {
                    'number': pr['number'],
                    'title': pr['title'],
                    'state': pr['state'],
                    'user': pr['user']?['login'],
                  })
              .toList() ??
          [];

      return ToolResult.success(
        'Found ${response.data.length} pull requests',
        data: {'pull_requests': prs},
      );
    } catch (e) {
      return ToolResult.failure('Failed to list PRs: $e');
    }
  }

  static Future<ToolResult> _createPr(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post(
        '/repos/${params['owner']}/${params['repo']}/pulls',
        data: {
          'title': params['title'],
          'head': params['head'],
          'base': params['base'],
          if (params['body'] != null) 'body': params['body'],
        },
      );

      return ToolResult.success(
        'Created PR #${response.data['number']}: ${response.data['title']}',
        data: response.data,
      );
    } catch (e) {
      return ToolResult.failure('Failed to create PR: $e');
    }
  }

  static Future<ToolResult> _deploy(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post(
        '/repos/${params['owner']}/${params['repo']}/actions/workflows/${params['workflow']}/dispatches',
        data: {
          'ref': params['ref'] ?? 'main',
        },
      );

      if (response.statusCode == 204) {
        return ToolResult.success(
          'Deployment triggered for ${params['workflow']} on ${params['ref'] ?? 'main'}',
        );
      }

      return ToolResult.failure('Failed to trigger deployment');
    } catch (e) {
      return ToolResult.failure('Failed to deploy: $e');
    }
  }
}
