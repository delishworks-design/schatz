import '../models/tool.dart';

class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._();
  factory ToolRegistry() => _instance;
  ToolRegistry._();

  final Map<String, List<Tool>> _toolsByPlugin = {};
  final Map<String, Tool> _allTools = {};

  void registerPluginTools(String pluginId, List<Tool> tools) {
    _toolsByPlugin[pluginId] = tools;
    for (final tool in tools) {
      _allTools[tool.fullName] = tool;
    }
  }

  void unregisterPlugin(String pluginId) {
    final tools = _toolsByPlugin.remove(pluginId);
    if (tools != null) {
      for (final tool in tools) {
        _allTools.remove(tool.fullName);
      }
    }
  }

  List<Tool> getAllTools() {
    return _allTools.values.toList();
  }

  List<Tool> getToolsForPlugin(String pluginId) {
    return _toolsByPlugin[pluginId] ?? [];
  }

  Tool? getTool(String fullName) {
    return _allTools[fullName];
  }

  Tool? findTool(String pluginId, String toolId) {
    final tools = _toolsByPlugin[pluginId];
    if (tools == null) return null;
    try {
      return tools.firstWhere((t) => t.id == toolId);
    } catch (_) {
      return null;
    }
  }

  List<Tool> searchTools(String query) {
    final lowerQuery = query.toLowerCase();
    return _allTools.values
        .where((tool) =>
            tool.name.toLowerCase().contains(lowerQuery) ||
            tool.description.toLowerCase().contains(lowerQuery) ||
            tool.fullName.toLowerCase().contains(lowerQuery))
        .toList();
  }

  List<Tool> getToolsByType(ToolType type) {
    return _allTools.values.where((t) => t.type == type).toList();
  }

  List<Tool> getToolsByCategory(String category) {
    return _allTools.values.where((t) => t.pluginId == category).toList();
  }

  Map<String, List<Tool>> get groupedByPlugin {
    return Map.from(_toolsByPlugin);
  }
}
