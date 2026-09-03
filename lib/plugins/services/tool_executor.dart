import 'dart:async';
import '../models/tool.dart';
import '../models/tool_result.dart';
import 'tool_registry.dart';
import '../../core/security/secure_storage.dart';

typedef ToolExecutor = Future<ToolResult> Function(Map<String, dynamic> params);

class ToolExecutorService {
  static final ToolExecutorService _instance = ToolExecutorService._();
  factory ToolExecutorService() => _instance;
  ToolExecutorService._();

  final ToolRegistry _registry = ToolRegistry();
  final SecureStorage _storage = SecureStorage();
  final Map<String, ToolExecutor> _executors = {};

  void registerExecutor(String pluginId, String toolId, ToolExecutor executor) {
    final key = '$pluginId.$toolId';
    _executors[key] = executor;
  }

  void unregisterExecutors(String pluginId) {
    _executors.removeWhere((key, _) => key.startsWith('$pluginId.'));
  }

  Future<ToolResult> execute(
      String fullName, Map<String, dynamic> params) async {
    final stopwatch = Stopwatch()..start();

    try {
      final tool = _registry.getTool(fullName);
      if (tool == null) {
        stopwatch.stop();
        return ToolResult.failure('Tool not found: $fullName');
      }

      final executor = _executors[fullName];
      if (executor == null) {
        stopwatch.stop();
        return ToolResult.failure('No executor registered for: $fullName');
      }

      if (tool.requiresAuth) {
        final hasAuth = await _checkAuth(tool.pluginId);
        if (!hasAuth) {
          stopwatch.stop();
          return ToolResult.failure(
              'Authentication required for: ${tool.pluginId}');
        }
      }

      final validationError = _validateParams(tool, params);
      if (validationError != null) {
        stopwatch.stop();
        return ToolResult.failure(validationError);
      }

      final result = await executor(params);
      stopwatch.stop();

      if (result.executionTime != null) {
        return result;
      }

      return ToolResult(
        success: result.success,
        content: result.content,
        data: result.data,
        error: result.error,
        toolId: fullName,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(
        'Execution failed: $e',
        toolId: fullName,
      );
    }
  }

  Future<List<ToolResult>> executeSequence(
    List<Map<String, dynamic>> toolCalls,
  ) async {
    final results = <ToolResult>[];

    for (final call in toolCalls) {
      final toolId = call['tool'] as String;
      final params = call['params'] as Map<String, dynamic>? ?? {};

      final result = await execute(toolId, params);
      results.add(result);

      if (!result.success) {
        break;
      }
    }

    return results;
  }

  Future<List<ToolResult>> executeParallel(
    List<Map<String, dynamic>> toolCalls,
  ) async {
    final futures = toolCalls.map((call) {
      final toolId = call['tool'] as String;
      final params = call['params'] as Map<String, dynamic>? ?? {};
      return execute(toolId, params);
    });

    return await Future.wait(futures);
  }

  Future<bool> _checkAuth(String pluginId) async {
    final token = await _storage.read('plugin_auth_$pluginId');
    return token != null && token.isNotEmpty;
  }

  String? _validateParams(Tool tool, Map<String, dynamic> params) {
    for (final entry in tool.parameters.entries) {
      final param = entry.value;
      final value = params[entry.key];

      if (param.required && (value == null || value.toString().isEmpty)) {
        return 'Missing required parameter: ${param.name}';
      }

      if (value != null &&
          param.options != null &&
          !param.options!.contains(value.toString())) {
        return 'Invalid value for ${param.name}: $value';
      }
    }
    return null;
  }
}
