import 'dart:convert';
import '../security/secure_storage.dart';
import 'storage_keys.dart';

class KeyMigrationService {
  final SecureStorage _storage = SecureStorage();

  Future<KeyMigrationResult> runMigrations() async {
    final results = <String, bool>{};
    bool needsRefresh = false;

    final currentVersion =
        int.tryParse(await _storage.read(StorageKeys.migrationVersion) ?? '0') ?? 0;

    if (currentVersion < 1) {
      final result = await _migrateToV1();
      results['v1_profile_keys'] = result;
      needsRefresh = needsRefresh || result;
    }

    if (currentVersion < StorageKeys.currentMigrationVersion) {
      await _storage.write(
        StorageKeys.migrationVersion,
        StorageKeys.currentMigrationVersion.toString(),
      );
    }

    return KeyMigrationResult(
      success: results.values.every((v) => v),
      migratedKeys: results,
      didMigrate: needsRefresh,
    );
  }

  Future<bool> _migrateToV1() async {
    bool anyMigrated = false;

    final profilesJson = await _storage.read(StorageKeys.providerProfiles);
    if (profilesJson == null || profilesJson.isEmpty) {
      return false;
    }

    try {
      final List<dynamic> profiles = jsonDecode(profilesJson);

      for (final profile in profiles) {
        final profileId = profile['id'] as String?;
        final typeName = profile['type'] as String?;
        final apiKeyRef = profile['apiKeyReference'] as String?;

        if (profileId == null || typeName == null) continue;

        final newKeyRef = StorageKeys.apiKeyReference(profileId);

        final newKeyExists = await _storage.containsKey(newKeyRef);
        if (newKeyExists) continue;

        String? legacyKeyRef;
        if (apiKeyRef != null && !apiKeyRef.startsWith(StorageConstants.profileIdPrefix)) {
          legacyKeyRef = apiKeyRef;
        } else {
          legacyKeyRef = StorageKeys.legacyApiKey(typeName.toLowerCase());
        }

        final legacyKey = await _storage.read(legacyKeyRef);
        if (legacyKey != null && legacyKey.isNotEmpty) {
          await _storage.write(newKeyRef, legacyKey);
          anyMigrated = true;
        }
      }

      if (anyMigrated) {
        await _storage.write(
          '${StorageConstants.apiKeyLegacyPrefix}openrouter',
          await _storage.read(StorageKeys.legacyApiKey('openrouter')) ?? '',
        );
        await _storage.write(
          '${StorageConstants.apiKeyLegacyPrefix}groq',
          await _storage.read(StorageKeys.legacyApiKey('groq')) ?? '',
        );
        await _storage.write(
          '${StorageConstants.apiKeyLegacyPrefix}gemini',
          await _storage.read(StorageKeys.legacyApiKey('gemini')) ?? '',
        );
        await _storage.write(
          '${StorageConstants.apiKeyLegacyPrefix}mistral',
          await _storage.read(StorageKeys.legacyApiKey('mistral')) ?? '',
        );
        await _storage.write(
          '${StorageConstants.apiKeyLegacyPrefix}cerebras',
          await _storage.read(StorageKeys.legacyApiKey('cerebras')) ?? '',
        );
        await _storage.write(
          '${StorageConstants.apiKeyLegacyPrefix}openai',
          await _storage.read(StorageKeys.legacyApiKey('openai')) ?? '',
        );
      }
    } catch (e) {
      return false;
    }

    return anyMigrated;
  }
}

class KeyMigrationResult {
  final bool success;
  final Map<String, bool> migratedKeys;
  final bool didMigrate;

  KeyMigrationResult({
    required this.success,
    required this.migratedKeys,
    required this.didMigrate,
  });
}
