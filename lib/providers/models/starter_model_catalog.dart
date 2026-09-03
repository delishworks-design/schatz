import '../models/provider_profile.dart';

enum ModelCostType {
  free,
  starter,
  trial,
  paid,
  unknown,
}

class ModelCostInfo {
  final String modelId;
  final String modelName;
  final ProviderType providerType;
  final ModelCostType costType;
  final String description;
  final bool supportsStreaming;
  final bool supportsVision;
  final int? contextLength;

  const ModelCostInfo({
    required this.modelId,
    required this.modelName,
    required this.providerType,
    required this.costType,
    this.description = '',
    this.supportsStreaming = true,
    this.supportsVision = false,
    this.contextLength,
  });
}

class StarterModelCatalog {
  StarterModelCatalog._();

  static const List<ModelCostInfo> openRouterFreeModels = [
    ModelCostInfo(
      modelId: 'google/gemini-2.0-flash-thinking-exp:free',
      modelName: 'Gemini 2.0 Flash Thinking (Free)',
      providerType: ProviderType.openrouter,
      costType: ModelCostType.free,
      description: 'Free tier with usage limits',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'anthropic/claude-3.5-haiku:free',
      modelName: 'Claude 3.5 Haiku (Free)',
      providerType: ProviderType.openrouter,
      costType: ModelCostType.free,
      description: 'Free tier with usage limits',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 200000,
    ),
    ModelCostInfo(
      modelId: 'meta-llama/llama-3.2-3b-instruct:free',
      modelName: 'Llama 3.2 3B (Free)',
      providerType: ProviderType.openrouter,
      costType: ModelCostType.free,
      description: 'Free tier with usage limits',
      supportsStreaming: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'qwen/qwen-2.5-7b-instruct:free',
      modelName: 'Qwen 2.5 7B (Free)',
      providerType: ProviderType.openrouter,
      costType: ModelCostType.free,
      description: 'Free tier with usage limits',
      supportsStreaming: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'mistralai/mistral-nemo:free',
      modelName: 'Mistral Nemo (Free)',
      providerType: ProviderType.openrouter,
      costType: ModelCostType.free,
      description: 'Free tier with usage limits',
      supportsStreaming: true,
      contextLength: 32768,
    ),
  ];

  static const List<ModelCostInfo> openRouterStarterModels = [
    ModelCostInfo(
      modelId: 'openrouter/auto',
      modelName: 'Auto (Best Available)',
      providerType: ProviderType.openrouter,
      costType: ModelCostType.starter,
      description: 'Automatically selects best model',
      supportsStreaming: true,
    ),
    ModelCostInfo(
      modelId: 'openrouter/openai/gpt-4o-mini',
      modelName: 'GPT-4o Mini',
      providerType: ProviderType.openrouter,
      costType: ModelCostType.paid,
      description: 'Fast, affordable GPT-4 class model',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 128000,
    ),
  ];

  static const List<ModelCostInfo> geminiStarterModels = [
    ModelCostInfo(
      modelId: 'gemini-1.5-flash',
      modelName: 'Gemini 1.5 Flash',
      providerType: ProviderType.gemini,
      costType: ModelCostType.free,
      description: 'Free tier available with quota limits',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 1000000,
    ),
    ModelCostInfo(
      modelId: 'gemini-1.5-flash-8b',
      modelName: 'Gemini 1.5 Flash 8B',
      providerType: ProviderType.gemini,
      costType: ModelCostType.free,
      description: 'Lighter, faster free tier model',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 1000000,
    ),
    ModelCostInfo(
      modelId: 'gemini-1.5-pro',
      modelName: 'Gemini 1.5 Pro',
      providerType: ProviderType.gemini,
      costType: ModelCostType.trial,
      description: 'Trial tier, then paid',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 2000000,
    ),
    ModelCostInfo(
      modelId: 'gemini-2.0-flash-exp',
      modelName: 'Gemini 2.0 Flash (Experimental)',
      providerType: ProviderType.gemini,
      costType: ModelCostType.trial,
      description: 'Experimental - trial tier',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 1000000,
    ),
  ];

  static const List<ModelCostInfo> groqStarterModels = [
    ModelCostInfo(
      modelId: 'llama-3.2-3b-preview',
      modelName: 'Llama 3.2 3B Preview',
      providerType: ProviderType.groq,
      costType: ModelCostType.starter,
      description: 'Fast inference, free tier available',
      supportsStreaming: true,
      contextLength: 8192,
    ),
    ModelCostInfo(
      modelId: 'llama-3.1-8b-instant',
      modelName: 'Llama 3.1 8B Instant',
      providerType: ProviderType.groq,
      costType: ModelCostType.starter,
      description: 'Fast inference, free tier available',
      supportsStreaming: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'mixtral-8x7b-32768',
      modelName: 'Mixtral 8x7B',
      providerType: ProviderType.groq,
      costType: ModelCostType.starter,
      description: 'Fast inference, free tier available',
      supportsStreaming: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'gemma2-9b-it',
      modelName: 'Gemma 2 9B',
      providerType: ProviderType.groq,
      costType: ModelCostType.starter,
      description: 'Fast inference, free tier available',
      supportsStreaming: true,
      contextLength: 8192,
    ),
  ];

  static const List<ModelCostInfo> openaiStarterModels = [
    ModelCostInfo(
      modelId: 'gpt-4o-mini',
      modelName: 'GPT-4o Mini',
      providerType: ProviderType.openai,
      costType: ModelCostType.starter,
      description: 'Affordable and fast',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 128000,
    ),
    ModelCostInfo(
      modelId: 'gpt-4o',
      modelName: 'GPT-4o',
      providerType: ProviderType.openai,
      costType: ModelCostType.paid,
      description: 'Most capable GPT-4 class model',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 128000,
    ),
    ModelCostInfo(
      modelId: 'gpt-4-turbo',
      modelName: 'GPT-4 Turbo',
      providerType: ProviderType.openai,
      costType: ModelCostType.paid,
      description: 'Previous generation flagship',
      supportsStreaming: true,
      supportsVision: true,
      contextLength: 128000,
    ),
  ];

  static const List<ModelCostInfo> mistralStarterModels = [
    ModelCostInfo(
      modelId: 'mistral-small-latest',
      modelName: 'Mistral Small',
      providerType: ProviderType.mistral,
      costType: ModelCostType.starter,
      description: 'Affordable and efficient',
      supportsStreaming: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'mistral-large-latest',
      modelName: 'Mistral Large',
      providerType: ProviderType.mistral,
      costType: ModelCostType.paid,
      description: 'Most capable Mistral model',
      supportsStreaming: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'codestral-latest',
      modelName: 'Codestral',
      providerType: ProviderType.mistral,
      costType: ModelCostType.paid,
      description: 'Code generation model',
      supportsStreaming: true,
      contextLength: 32768,
    ),
  ];

  static const List<ModelCostInfo> cerebrasStarterModels = [
    ModelCostInfo(
      modelId: 'llama-3.3-70b',
      modelName: 'Llama 3.3 70B',
      providerType: ProviderType.cerebras,
      costType: ModelCostType.trial,
      description: 'Trial credits, then paid',
      supportsStreaming: true,
      contextLength: 32768,
    ),
    ModelCostInfo(
      modelId: 'qwen-2.5-72b-instruct',
      modelName: 'Qwen 2.5 72B',
      providerType: ProviderType.cerebras,
      costType: ModelCostType.trial,
      description: 'Trial credits, then paid',
      supportsStreaming: true,
      contextLength: 32768,
    ),
  ];

  static List<ModelCostInfo> getStarterModels(ProviderType type) {
    switch (type) {
      case ProviderType.openrouter:
        return [...openRouterFreeModels, ...openRouterStarterModels];
      case ProviderType.gemini:
        return geminiStarterModels;
      case ProviderType.groq:
        return groqStarterModels;
      case ProviderType.openai:
        return openaiStarterModels;
      case ProviderType.mistral:
        return mistralStarterModels;
      case ProviderType.cerebras:
        return cerebrasStarterModels;
      case ProviderType.custom:
        return [];
    }
  }

  static List<ModelCostInfo> getFreeModels(ProviderType type) {
    switch (type) {
      case ProviderType.openrouter:
        return openRouterFreeModels;
      case ProviderType.gemini:
        return geminiStarterModels.where((m) => m.costType == ModelCostType.free).toList();
      case ProviderType.groq:
        return groqStarterModels.where((m) => m.costType == ModelCostType.starter).toList();
      case ProviderType.openai:
        return [];
      case ProviderType.mistral:
        return [];
      case ProviderType.cerebras:
        return [];
      case ProviderType.custom:
        return [];
    }
  }

  static ModelCostInfo? getDefaultStarterModel(ProviderType type) {
    final models = getStarterModels(type);
    if (models.isEmpty) return null;

    final freeModels = models.where((m) => m.costType == ModelCostType.free).toList();
    if (freeModels.isNotEmpty) return freeModels.first;

    final starterModels = models.where((m) => m.costType == ModelCostType.starter).toList();
    if (starterModels.isNotEmpty) return starterModels.first;

    return models.first;
  }

  static List<ProviderModel> starterModelsToProviderModels(ProviderType type, String providerId) {
    return getStarterModels(type).map((info) {
      return ProviderModel(
        id: info.modelId,
        name: info.modelName,
        providerId: providerId,
        supportsStreaming: info.supportsStreaming,
        supportsVision: info.supportsVision,
        contextLength: info.contextLength,
        description: info.description,
      );
    }).toList();
  }
}
