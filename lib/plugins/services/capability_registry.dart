import 'dart:convert';
import '../models/tool.dart';
import 'tool_registry.dart';

class CapabilityRegistry {
  static final CapabilityRegistry _instance = CapabilityRegistry._();
  factory CapabilityRegistry() => _instance;
  CapabilityRegistry._();

  final ToolRegistry _toolRegistry = ToolRegistry();
  List<Map<String, dynamic>>? _cachedOpenAITools;
  String? _cachedSystemPrompt;
  List<Tool>? _cachedTools;

  List<Tool> getAvailableTools({String? pluginFilter}) {
    final allTools = _toolRegistry.getAllTools();
    if (pluginFilter != null) {
      return allTools.where((t) => t.pluginId == pluginFilter).toList();
    }
    return allTools;
  }

  List<Map<String, dynamic>> getToolSchemasForProvider(String providerType) {
    switch (providerType.toLowerCase()) {
      case 'openai':
      case 'openrouter':
      case 'groq':
      case 'cerebras':
        return toOpenAITools();
      case 'anthropic':
        return toOpenAITools();
      case 'gemini':
        return toOpenAITools();
      default:
        return toOpenAITools();
    }
  }

  List<Map<String, dynamic>> toOpenAITools() {
    if (_cachedOpenAITools != null && _cachedTools == _toolRegistry.getAllTools()) {
      return _cachedOpenAITools!;
    }

    final tools = _toolRegistry.getAllTools();
    final schemas = tools.map((tool) {
      final properties = <String, dynamic>{};
      final required = <String>[];

      for (final entry in tool.parameters.entries) {
        final param = entry.value;
        properties[param.name] = {
          'type': _mapParameterType(param.type),
          'description': param.description,
        };
        if (param.options != null) {
          properties[param.name]['enum'] = param.options;
        }
        if (param.defaultValue != null) {
          properties[param.name]['default'] = param.defaultValue;
        }
        if (param.required) {
          required.add(param.name);
        }
      }

      return {
        'type': 'function',
        'function': {
          'name': tool.fullName.replaceAll('.', '_'),
          'description': tool.description,
          'parameters': {
            'type': 'object',
            'properties': properties,
            'required': required,
          },
        },
      };
    }).toList();

    _cachedOpenAITools = schemas;
    _cachedTools = _toolRegistry.getAllTools();
    return schemas;
  }

  String buildSystemPromptToolsSection() {
    if (_cachedSystemPrompt != null && _cachedTools == _toolRegistry.getAllTools()) {
      return _cachedSystemPrompt!;
    }

    final tools = _toolRegistry.getAllTools();
    if (tools.isEmpty) {
      _cachedSystemPrompt = '';
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('## Available Tools');
    buffer.writeln('You have access to the following tools. Use them when appropriate.');
    buffer.writeln('To use a tool, respond with a JSON code block in this exact format:');
    buffer.writeln('```tool_call');
    buffer.writeln('{"tool": "tool_name", "args": {"param": "value"}}');
    buffer.writeln('```');
    buffer.writeln();

    final grouped = <String, List<Tool>>{};
    for (final tool in tools) {
      grouped.putIfAbsent(tool.pluginId, () => []).add(tool);
    }

    for (final entry in grouped.entries) {
      buffer.writeln('### ${entry.key}');
      for (final tool in entry.value) {
        buffer.writeln('- **${tool.fullName}**: ${tool.description}');
        if (tool.parameters.isNotEmpty) {
          buffer.writeln('  Parameters:');
          for (final param in tool.parameters.values) {
            final req = param.required ? ' (required)' : '';
            buffer.writeln('    - ${param.name} (${param.type.name}): ${param.description}$req');
          }
        }
      }
      buffer.writeln();
    }

    _cachedSystemPrompt = buffer.toString();
    _cachedTools = _toolRegistry.getAllTools();
    return _cachedSystemPrompt!;
  }

  void invalidateCache() {
    _cachedOpenAITools = null;
    _cachedSystemPrompt = null;
    _cachedTools = null;
  }

  String _mapParameterType(ToolParameterType type) {
    switch (type) {
      case ToolParameterType.string:
        return 'string';
      case ToolParameterType.int:
        return 'integer';
      case ToolParameterType.double:
        return 'number';
      case ToolParameterType.bool:
        return 'boolean';
      case ToolParameterType.list:
        return 'array';
      case ToolParameterType.map:
        return 'object';
    }
  }
}
