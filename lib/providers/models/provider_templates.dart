import 'package:uuid/uuid.dart';
import 'provider_profile.dart';

class ProviderTemplates {
  ProviderTemplates._();

  static final List<ProviderProfile> templates = [
    ProviderProfile(
      id: const Uuid().v4(),
      displayName: 'OpenRouter',
      type: ProviderType.openrouter,
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKeyReference: 'profile_openrouter',
      streamingEnabled: true,
      visionEnabled: true,
    ),
    ProviderProfile(
      id: const Uuid().v4(),
      displayName: 'Groq',
      type: ProviderType.groq,
      baseUrl: 'https://api.groq.com/openai/v1',
      apiKeyReference: 'profile_groq',
      streamingEnabled: true,
      visionEnabled: false,
    ),
    ProviderProfile(
      id: const Uuid().v4(),
      displayName: 'Google Gemini',
      type: ProviderType.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      apiKeyReference: 'profile_gemini',
      streamingEnabled: true,
      visionEnabled: true,
    ),
    ProviderProfile(
      id: const Uuid().v4(),
      displayName: 'Mistral',
      type: ProviderType.mistral,
      baseUrl: 'https://api.mistral.ai/v1',
      apiKeyReference: 'profile_mistral',
      streamingEnabled: true,
      visionEnabled: false,
    ),
    ProviderProfile(
      id: const Uuid().v4(),
      displayName: 'Cerebras',
      type: ProviderType.cerebras,
      baseUrl: 'https://api.cerebras.ai/v1',
      apiKeyReference: 'profile_cerebras',
      streamingEnabled: true,
      visionEnabled: false,
    ),
    ProviderProfile(
      id: const Uuid().v4(),
      displayName: 'OpenAI',
      type: ProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      apiKeyReference: 'profile_openai',
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

  static ProviderProfile? getTemplateByType(ProviderType type) {
    try {
      return templates.firstWhere((t) => t.type == type);
    } catch (_) {
      return null;
    }
  }
}
