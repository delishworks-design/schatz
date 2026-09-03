import 'provider_profile.dart';

class ProviderTemplates {
  ProviderTemplates._();

  static final List<ProviderProfile> templates = [
    ProviderProfile(
      displayName: 'OpenRouter',
      type: ProviderType.openrouter,
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKeyReference: 'openrouter',
      streamingEnabled: true,
      visionEnabled: true,
    ),
    ProviderProfile(
      displayName: 'Groq',
      type: ProviderType.groq,
      baseUrl: 'https://api.groq.com/openai/v1',
      apiKeyReference: 'groq',
      streamingEnabled: true,
      visionEnabled: false,
    ),
    ProviderProfile(
      displayName: 'Google Gemini',
      type: ProviderType.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      apiKeyReference: 'gemini',
      streamingEnabled: true,
      visionEnabled: true,
    ),
    ProviderProfile(
      displayName: 'Mistral',
      type: ProviderType.mistral,
      baseUrl: 'https://api.mistral.ai/v1',
      apiKeyReference: 'mistral',
      streamingEnabled: true,
      visionEnabled: false,
    ),
    ProviderProfile(
      displayName: 'Cerebras',
      type: ProviderType.cerebras,
      baseUrl: 'https://api.cerebras.ai/v1',
      apiKeyReference: 'cerebras',
      streamingEnabled: true,
      visionEnabled: false,
    ),
    ProviderProfile(
      displayName: 'OpenAI',
      type: ProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      apiKeyReference: 'openai',
      streamingEnabled: true,
      visionEnabled: true,
    ),
  ];

  static ProviderProfile? getTemplate(String name) {
    try {
      return templates.firstWhere(
        (t) => t.displayName.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
