import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._();
  factory SecureStorage() => _instance;
  SecureStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStorage write error: $e');
      rethrow;
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureStorage read error: $e');
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStorage delete error: $e');
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('SecureStorage deleteAll error: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      debugPrint('SecureStorage readAll error: $e');
      return {};
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('SecureStorage containsKey error: $e');
      return false;
    }
  }

  Future<void> writeApiKey(String providerId, String apiKey) async {
    try {
      await write('api_key_$providerId', apiKey);
    } catch (e) {
      debugPrint('SecureStorage writeApiKey error: $e');
      rethrow;
    }
  }

  Future<String?> readApiKey(String providerId) async {
    try {
      return await read('api_key_$providerId');
    } catch (e) {
      debugPrint('SecureStorage readApiKey error: $e');
      return null;
    }
  }

  Future<void> deleteApiKey(String providerId) async {
    try {
      await delete('api_key_$providerId');
    } catch (e) {
      debugPrint('SecureStorage deleteApiKey error: $e');
      rethrow;
    }
  }
}
