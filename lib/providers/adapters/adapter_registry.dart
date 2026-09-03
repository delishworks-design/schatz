import '../models/provider_profile.dart';
import 'base_provider_adapter.dart';
import 'openai_adapter.dart';
import 'gemini_adapter.dart';

class AdapterRegistry {
  static final AdapterRegistry _instance = AdapterRegistry._();
  factory AdapterRegistry() => _instance;
  AdapterRegistry._();

  final Map<ProviderType, BaseProviderAdapter> _adapters = {};

  BaseProviderAdapter _openAIAdapter = OpenAIAdapter();
  BaseProviderAdapter _geminiAdapter = GeminiAdapter();

  BaseProviderAdapter getAdapter(ProviderType type) {
    if (_adapters.containsKey(type)) {
      return _adapters[type]!;
    }

    final adapter = _createAdapter(type);
    _adapters[type] = adapter;
    return adapter;
  }

  BaseProviderAdapter _createAdapter(ProviderType type) {
    switch (type) {
      case ProviderType.gemini:
        return _geminiAdapter;
      default:
        return _openAIAdapter;
    }
  }

  bool supportsStreaming(ProviderType type) {
    switch (type) {
      case ProviderType.gemini:
        return true;
      default:
        return true;
    }
  }

  bool supportsTools(ProviderType type) {
    switch (type) {
      case ProviderType.gemini:
        return false;
      default:
        return true;
    }
  }

  void dispose() {
    _openAIAdapter.dispose();
    _geminiAdapter.dispose();
    _adapters.clear();
  }
}
