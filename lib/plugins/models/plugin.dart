enum PluginCategory {
  development,
  deployment,
  database,
  execution,
  payment,
  backend,
  infrastructure,
}

class Plugin {
  final String id;
  final String name;
  final String description;
  final PluginCategory category;
  final String version;
  final String author;
  final String? iconUrl;
  final bool enabled;
  final Map<String, dynamic> settings;
  final List<String> requiredPermissions;
  final DateTime installedAt;
  final DateTime? updatedAt;
  
  Plugin({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.version = '1.0.0',
    this.author = 'Schatz',
    this.iconUrl,
    this.enabled = true,
    this.settings = const {},
    this.requiredPermissions = const [],
    DateTime? installedAt,
    this.updatedAt,
  }) : installedAt = installedAt ?? DateTime.now();
  
  Plugin copyWith({
    String? name,
    String? description,
    PluginCategory? category,
    String? version,
    bool? enabled,
    Map<String, dynamic>? settings,
    DateTime? updatedAt,
  }) {
    return Plugin(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      version: version ?? this.version,
      author: author,
      iconUrl: iconUrl,
      enabled: enabled ?? this.enabled,
      settings: settings ?? this.settings,
      requiredPermissions: requiredPermissions,
      installedAt: installedAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category.name,
    'version': version,
    'author': author,
    'iconUrl': iconUrl,
    'enabled': enabled,
    'settings': settings,
    'requiredPermissions': requiredPermissions,
    'installedAt': installedAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  
  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unnamed Plugin',
      description: json['description'] ?? '',
      category: PluginCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PluginCategory.development,
      ),
      version: json['version'] ?? '1.0.0',
      author: json['author'] ?? 'Schatz',
      iconUrl: json['iconUrl'],
      enabled: json['enabled'] ?? true,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      requiredPermissions: List<String>.from(json['requiredPermissions'] ?? []),
      installedAt: json['installedAt'] != null ? DateTime.parse(json['installedAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}
