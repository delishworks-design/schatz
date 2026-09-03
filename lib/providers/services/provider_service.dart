import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/provider_profile.dart';
import '../adapters/openai_adapter.dart';
import '../../core/security/secure_storage.dart';

class ProviderService {
  final SecureStorage _storage = SecureStorage();
  final OpenAIAdapter _adapter = OpenAIAdapter();
  List<ProviderProfile>? _cachedProfiles;

  Future<List<ProviderProfile>> getProfiles() async {
    if (_cachedProfiles != null) return _cachedProfiles!;

    final data = await _storage.read('provider_profiles');
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
    await _storage.write('provider_profiles',
        jsonEncode(profiles.map((p) => p.toJson()).toList()));
    _cachedProfiles = profiles;
  }

  Future<void> deleteProfile(String profileId) async {
    final profiles = await getProfiles();
    profiles.removeWhere((p) => p.id == profileId);
    await _storage.write('provider_profiles',
        jsonEncode(profiles.map((p) => p.toJson()).toList()));
    _cachedProfiles = profiles;
  }

  Future<List<ProviderModel>> listModels(ProviderProfile profile) async {
    return await _adapter.listModels(profile);
  }

  Stream<String> streamMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
  }) {
    return _adapter.streamMessage(
      profile: profile,
      messages: messages,
      systemPrompt: systemPrompt,
      cancelToken: cancelToken,
    );
  }

  Future<String> sendMessage({
    required ProviderProfile profile,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
  }) async {
    return await _adapter.sendMessage(
      profile: profile,
      messages: messages,
      systemPrompt: systemPrompt,
      cancelToken: cancelToken,
    );
  }

  Future<ConnectionTestResult> testConnection(ProviderProfile profile) async {
    return await _adapter.testConnection(profile);
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

  void clearCache() {
    _cachedProfiles = null;
  }

  void dispose() {
    _adapter.dispose();
  }
}
