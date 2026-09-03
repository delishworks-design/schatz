import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/provider_profile.dart';
import '../adapters/adapter_registry.dart';
import '../adapters/base_provider_adapter.dart';
import '../../core/security/secure_storage.dart';
import '../../core/storage/storage_keys.dart';

class ProviderService {
  final SecureStorage _storage = SecureStorage();
  final AdapterRegistry _registry = AdapterRegistry();
  List<ProviderProfile>? _cachedProfiles;

  Future<List<ProviderProfile>> getProfiles() async {
    if (_cachedProfiles != null) return _cachedProfiles!;

    final data = await _storage.read(StorageKeys.providerProfiles);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      _cachedProfiles =
          jsonList.map((j) => ProviderProfile.fromJson(j)).toList();
      return _cachedProfiles!;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfile(ProviderProfile profile) async {
    final profiles = await getProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await _storage.write(StorageKeys.providerProfiles,
        jsonEncode(profiles.map((p) => p.toJson()).toList()));
    _cachedProfiles = profiles;
  }

  Future<void> deleteProfile(String profileId) async {
    final profiles = await getProfiles();
    profiles.removeWhere((p) => p.id == profileId);
    await _storage.write(StorageKeys.providerProfiles,
        jsonEncode(profiles.map((p) => p.toJson()).toList()));
    _cachedProfiles = profiles;
  }

  Future<List<ProviderModel>> listModels(ProviderProfile profile, {String? apiKeyOverride}) async {
    final adapter = _registry.getAdapter(profile.type);
    return await adapter.listModels(profile, apiKeyOverride: apiKeyOverride);
  }

  Stream<String> streamMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
    String? apiKeyOverride,
  }) {
    final adapter = _registry.getAdapter(profile.type);
    return adapter.streamMessage(
      profile: profile,
      messages: messages,
      systemPrompt: systemPrompt,
      cancelToken: cancelToken,
      tools: tools,
      apiKeyOverride: apiKeyOverride,
    );
  }

  Future<String> sendMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
    List<Map<String, dynamic>>? tools,
    String? apiKeyOverride,
  }) async {
    final adapter = _registry.getAdapter(profile.type);
    return await adapter.sendMessage(
      profile: profile,
      messages: messages,
      systemPrompt: systemPrompt,
      cancelToken: cancelToken,
      tools: tools,
      apiKeyOverride: apiKeyOverride,
    );
  }

  Future<ConnectionTestResult> testConnection(ProviderProfile profile, {String? apiKeyOverride}) async {
    final adapter = _registry.getAdapter(profile.type);
    return await adapter.testConnection(profile, apiKeyOverride: apiKeyOverride);
  }

  ProviderProfile? findProviderForModel(String modelName) {
    final profiles = _cachedProfiles;
    if (profiles == null || profiles.isEmpty) return null;

    for (final profile in profiles) {
      if (profile.availableModels.any((m) => m.name == modelName)) {
        return profile;
      }
    }
    return null;
  }

  ProviderProfile? findProviderById(String providerId) {
    final profiles = _cachedProfiles;
    if (profiles == null || profiles.isEmpty) return null;

    for (final profile in profiles) {
      if (profile.id == providerId) {
        return profile;
      }
    }
    return null;
  }

  void clearCache() {
    _cachedProfiles = null;
  }

  void dispose() {
    _registry.dispose();
  }
}
