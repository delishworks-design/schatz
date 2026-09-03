enum ToolType {
  read,
  write,
  execute,
  search,
  manage,
}

enum ToolParameterType {
  string,
  int,
  double,
  bool,
  list,
  map,
}

class Tool {
  final String id;
  final String name;
  final String description;
  final String pluginId;
  final ToolType type;
  final Map<String, ToolParameter> parameters;
  final String? example;
  final bool requiresAuth;
  
  const Tool({
    required this.id,
    required this.name,
    required this.description,
    required this.pluginId,
    required this.type,
    this.parameters = const {},
    this.example,
    this.requiresAuth = true,
  });
  
  String get fullName => '$pluginId.$id';
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'pluginId': pluginId,
    'type': type.name,
    'parameters': parameters.map((k, v) => MapEntry(k, v.toJson())),
    'example': example,
    'requiresAuth': requiresAuth,
  };
  
  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unnamed Tool',
      description: json['description'] ?? '',
      pluginId: json['pluginId'] ?? '',
      type: ToolType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ToolType.read,
      ),
      parameters: (json['parameters'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, ToolParameter.fromJson(v)),
      ) ?? {},
      example: json['example'],
      requiresAuth: json['requiresAuth'] ?? true,
    );
  }
}

class ToolParameter {
  final String name;
  final String description;
  final ToolParameterType type;
  final bool required;
  final dynamic defaultValue;
  final List<String>? options;
  
  const ToolParameter({
    required this.name,
    required this.description,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.options,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'type': type.name,
    'required': required,
    'defaultValue': defaultValue,
    'options': options,
  };
  
  factory ToolParameter.fromJson(Map<String, dynamic> json) {
    return ToolParameter(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: ToolParameterType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ToolParameterType.string,
      ),
      required: json['required'] ?? false,
      defaultValue: json['defaultValue'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
    );
  }
}
