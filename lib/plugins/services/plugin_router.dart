import 'dart:convert';
import '../../core/security/secure_storage.dart';
import '../models/tool.dart';
import '../models/tool_result.dart';
import 'tool_registry.dart';
import 'tool_executor.dart';
import 'plugin_service.dart';

class PluginRouter {
  static final PluginRouter _instance = PluginRouter._();
  factory PluginRouter() => _instance;
  PluginRouter._();

  final ToolRegistry _toolRegistry = ToolRegistry();
  final ToolExecutorService _toolExecutor = ToolExecutorService();
  final PluginService _pluginService = PluginService();

  Future<ToolResult> route(String toolFullName, Map<String, dynamic> params) async {
    final tool = _toolRegistry.getTool(toolFullName);
    if (tool == null) {
      return ToolResult.failure('Tool not found: $toolFullName', toolId: toolFullName);
    }

    final enabledTools = await _pluginService.getEnabledTools();
    final isEnabled = enabledTools.any((t) => t.fullName == toolFullName);
    if (!isEnabled) {
      return ToolResult.failure('Tool is disabled: $toolFullName', toolId: toolFullName);
    }

    if (tool.requiresAuth) {
      final hasAuth = await _checkAuth(tool);
      if (!hasAuth) {
        return ToolResult.failure(
          'Authentication required for ${tool.pluginId}. Configure API key in plugin settings.',
          toolId: toolFullName,
        );
      }
    }

    final validationResult = _validateParams(tool, params);
    if (validationResult != null) {
      return ToolResult.failure(validationResult, toolId: toolFullName);
    }

    return await _toolExecutor.execute(toolFullName, params);
  }

  Future<List<ToolResult>> routeSequence(List<Map<String, dynamic>> toolCalls) async {
    final results = <ToolResult>[];
    for (final call in toolCalls) {
      final toolName = call['tool'] as String? ?? '';
      final args = call['args'] as Map<String, dynamic>? ?? {};
      final result = await route(toolName, args);
      results.add(result);
      if (!result.success) break;
    }
    return results;
  }

  Future<List<ToolResult>> routeParallel(List<Map<String, dynamic>> toolCalls) async {
    final futures = toolCalls.map((call) {
      final toolName = call['tool'] as String? ?? '';
      final args = call['args'] as Map<String, dynamic>? ?? {};
      return route(toolName, args);
    }).toList();
    return await Future.wait(futures);
  }

  ToolCall? parseToolCall(String text) {
    final regex = RegExp(r'```tool_call\s*\n(.*?)\n```', dotAll: true);
    final match = regex.firstMatch(text);
    if (match == null) return null;

    try {
      final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      final toolName = json['tool'] as String?;
      final args = json['args'] as Map<String, dynamic>? ?? {};

      if (toolName == null) return null;

      final normalizedToolName = toolName.replaceAll('_', '.');
      final tool = _toolRegistry.getTool(normalizedToolName);
      if (tool == null) return null;

      return ToolCall(
        toolFullName: normalizedToolName,
        arguments: args,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _checkAuth(Tool tool) async {
    final storage = SecureStorage();
    final pluginService = PluginService();
    final plugins = await pluginService.getInstalledPlugins();
    final plugin = plugins.where((p) => p.id == tool.pluginId).firstOrNull;
    if (plugin == null) return false;

    final settings = plugin.settings;
    final hasToken = settings.values.any((v) =>
        v is String && v.isNotEmpty && v != 'null');
    return hasToken;
  }

  String? _validateParams(Tool tool, Map<String, dynamic> params) {
    for (final entry in tool.parameters.entries) {
      final param = entry.value;
      if (param.required && !params.containsKey(param.name)) {
        return 'Missing required parameter: ${param.name}';
      }
      if (params.containsKey(param.name) && param.options != null) {
        final value = params[param.name]?.toString();
        if (value != null && !param.options!.contains(value)) {
          return 'Invalid value for ${param.name}. Must be one of: ${param.options!.join(', ')}';
        }
      }
    }
    return null;
  }
}

class ToolCall {
  final String toolFullName;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.toolFullName,
    required this.arguments,
  });
}
