import 'package:uuid/uuid.dart';

enum ProviderType {
  openai,
  gemini,
  groq,
  openrouter,
  mistral,
  cerebras,
  custom,
}

class ProviderProfile {
  final String id;
  final String displayName;
  final ProviderType type;
  final String baseUrl;
  final String apiKeyReference;
  final String? selectedModel;
  final List<ProviderModel> availableModels;
  final double temperature;
  final int maxTokens;
  final double topP;
  final bool streamingEnabled;
  final bool visionEnabled;
  final bool audioEnabled;
  final bool toolCallingEnabled;
  final bool structuredOutputEnabled;
  final Map<String, String> customHeaders;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  ProviderProfile({
    String? id,
    required this.displayName,
    required this.type,
    required this.baseUrl,
    required this.apiKeyReference,
    this.selectedModel,
    this.availableModels = const [],
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.topP = 1.0,
    this.streamingEnabled = true,
    this.visionEnabled = false,
    this.audioEnabled = false,
    this.toolCallingEnabled = false,
    this.structuredOutputEnabled = false,
    this.customHeaders = const {},
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
  
  ProviderProfile copyWith({
    String? displayName,
    ProviderType? type,
    String? baseUrl,
    String? apiKeyReference,
    String? selectedModel,
    List<ProviderModel>? availableModels,
    double? temperature,
    int? maxTokens,
    double? topP,
    bool? streamingEnabled,
    bool? visionEnabled,
    bool? audioEnabled,
    bool? toolCallingEnabled,
    bool? structuredOutputEnabled,
    Map<String, String>? customHeaders,
    bool? enabled,
  }) {
    return ProviderProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKeyReference: apiKeyReference ?? this.apiKeyReference,
      selectedModel: selectedModel ?? this.selectedModel,
      availableModels: availableModels ?? this.availableModels,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
      visionEnabled: visionEnabled ?? this.visionEnabled,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      toolCallingEnabled: toolCallingEnabled ?? this.toolCallingEnabled,
      structuredOutputEnabled: structuredOutputEnabled ?? this.structuredOutputEnabled,
      customHeaders: customHeaders ?? this.customHeaders,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'type': type.name,
    'baseUrl': baseUrl,
    'apiKeyReference': apiKeyReference,
    'selectedModel': selectedModel,
    'availableModels': availableModels.map((m) => m.toJson()).toList(),
    'temperature': temperature,
    'maxTokens': maxTokens,
    'topP': topP,
    'streamingEnabled': streamingEnabled,
    'visionEnabled': visionEnabled,
    'audioEnabled': audioEnabled,
    'toolCallingEnabled': toolCallingEnabled,
    'structuredOutputEnabled': structuredOutputEnabled,
    'customHeaders': customHeaders,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  
  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    return ProviderProfile(
      id: json['id'] ?? const Uuid().v4(),
      displayName: json['displayName'] ?? 'Unnamed Provider',
      type: ProviderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ProviderType.custom,
      ),
      baseUrl: json['baseUrl'] ?? '',
      apiKeyReference: json['apiKeyReference'] ?? '',
      selectedModel: json['selectedModel'],
      availableModels: (json['availableModels'] as List?)
          ?.map((m) => ProviderModel.fromJson(m))
          .toList() ?? [],
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] ?? 4096,
      topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
      streamingEnabled: json['streamingEnabled'] ?? true,
      visionEnabled: json['visionEnabled'] ?? false,
      audioEnabled: json['audioEnabled'] ?? false,
      toolCallingEnabled: json['toolCallingEnabled'] ?? false,
      structuredOutputEnabled: json['structuredOutputEnabled'] ?? false,
      customHeaders: Map<String, String>.from(json['customHeaders'] ?? {}),
      enabled: json['enabled'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}

class ProviderModel {
  final String id;
  final String name;
  final String? providerId;
  final bool supportsVision;
  final bool supportsAudio;
  final bool supportsStreaming;
  final bool supportsToolCalling;
  final int? contextLength;
  final String? description;
  
  ProviderModel({
    required this.id,
    required this.name,
    this.providerId,
    this.supportsVision = false,
    this.supportsAudio = false,
    this.supportsStreaming = true,
    this.supportsToolCalling = false,
    this.contextLength,
    this.description,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'providerId': providerId,
    'supportsVision': supportsVision,
    'supportsAudio': supportsAudio,
    'supportsStreaming': supportsStreaming,
    'supportsToolCalling': supportsToolCalling,
    'contextLength': contextLength,
    'description': description,
  };
  
  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'],
      name: json['name'],
      providerId: json['providerId'],
      supportsVision: json['supportsVision'] ?? false,
      supportsAudio: json['supportsAudio'] ?? false,
      supportsStreaming: json['supportsStreaming'] ?? true,
      supportsToolCalling: json['supportsToolCalling'] ?? false,
      contextLength: json['contextLength'],
      description: json['description'],
    );
  }
}
