class StorageKeys {
  StorageKeys._();

  static const String onboardingComplete = 'onboarding_complete';
  static const String activeProviderId = 'active_provider_id';
  static const String providerProfiles = 'provider_profiles';
  static const String migrationVersion = 'migration_version';
  static const int currentMigrationVersion = 1;

  static String apiKeyReference(String providerId) => 'api_key_$providerId';
  static String legacyApiKey(String typeName) => 'api_key_$typeName';

  static const List<String> legacyApiKeySlots = [
    'api_key_openrouter',
    'api_key_groq',
    'api_key_gemini',
    'api_key_mistral',
    'api_key_cerebras',
    'api_key_openai',
    'api_key_custom',
  ];
}

class StorageConstants {
  StorageConstants._();

  static const String profileIdPrefix = 'profile_';
  static const String apiKeyPrefix = 'api_key_';
  static const String apiKeyLegacyPrefix = 'api_key_legacy_';
}
