import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/security/secure_storage.dart';

class DownloadedModel {
  final String id;
  final String name;
  final String size;
  final String quantization;
  final int contextLength;
  final double ramRequired;
  final DateTime downloadedAt;
  final String filePath;
  
  DownloadedModel({
    required this.id,
    required this.name,
    required this.size,
    required this.quantization,
    required this.contextLength,
    required this.ramRequired,
    required this.downloadedAt,
    required this.filePath,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'quantization': quantization,
    'contextLength': contextLength,
    'ramRequired': ramRequired,
    'downloadedAt': downloadedAt.toIso8601String(),
    'filePath': filePath,
  };
  
  factory DownloadedModel.fromJson(Map<String, dynamic> json) {
    return DownloadedModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      size: json['size'] ?? '',
      quantization: json['quantization'] ?? '',
      contextLength: json['contextLength'] ?? 2048,
      ramRequired: (json['ramRequired'] as num?)?.toDouble() ?? 2.0,
      downloadedAt: json['downloadedAt'] != null 
          ? DateTime.parse(json['downloadedAt']) 
          : DateTime.now(),
      filePath: json['filePath'] ?? '',
    );
  }
}

class AvailableModel {
  final String id;
  final String name;
  final String description;
  final double sizeGB;
  final String quantization;
  final int contextLength;
  final double ramRequired;
  final String category;
  final String downloadUrl;
  
  AvailableModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sizeGB,
    required this.quantization,
    required this.contextLength,
    required this.ramRequired,
    required this.category,
    required this.downloadUrl,
  });
}

class ModelDownloader {
  final SecureStorage _storage = SecureStorage();
  
  Future<List<DownloadedModel>> getDownloadedModels() async {
    final data = await _storage.read('downloaded_models');
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((j) => DownloadedModel.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }
  
  Future<List<AvailableModel>> getAvailableModels() async {
    return [
      AvailableModel(
        id: 'phi-2-q4',
        name: 'Phi-2 (Q4)',
        description: 'Microsoft Phi-2 2.7B - Fast and efficient',
        sizeGB: 1.5,
        quantization: 'Q4_K_M',
        contextLength: 2048,
        ramRequired: 2.0,
        category: 'small',
        downloadUrl: 'https://huggingface.co/models/phi-2-q4',
      ),
      AvailableModel(
        id: 'phi-2-q8',
        name: 'Phi-2 (Q8)',
        description: 'Microsoft Phi-2 2.7B - Higher quality',
        sizeGB: 2.8,
        quantization: 'Q8_0',
        contextLength: 2048,
        ramRequired: 3.5,
        category: 'small',
        downloadUrl: 'https://huggingface.co/models/phi-2-q8',
      ),
      AvailableModel(
        id: 'llama-3.2-3b-q4',
        name: 'Llama 3.2 3B (Q4)',
        description: 'Meta Llama 3.2 3B - Balanced performance',
        sizeGB: 2.0,
        quantization: 'Q4_K_M',
        contextLength: 4096,
        ramRequired: 3.0,
        category: 'small',
        downloadUrl: 'https://huggingface.co/models/llama-3.2-3b-q4',
      ),
      AvailableModel(
        id: 'mistral-7b-q4',
        name: 'Mistral 7B (Q4)',
        description: 'Mistral AI 7B - High quality responses',
        sizeGB: 4.0,
        quantization: 'Q4_K_M',
        contextLength: 8192,
        ramRequired: 6.0,
        category: 'medium',
        downloadUrl: 'https://huggingface.co/models/mistral-7b-q4',
      ),
      AvailableModel(
        id: 'llama-3.1-8b-q4',
        name: 'Llama 3.1 8B (Q4)',
        description: 'Meta Llama 3.1 8B - Latest generation',
        sizeGB: 4.5,
        quantization: 'Q4_K_M',
        contextLength: 8192,
        ramRequired: 6.0,
        category: 'medium',
        downloadUrl: 'https://huggingface.co/models/llama-3.1-8b-q4',
      ),
      AvailableModel(
        id: 'gemma-2-9b-q4',
        name: 'Gemma 2 9B (Q4)',
        description: 'Google Gemma 2 9B - Excellent reasoning',
        sizeGB: 5.5,
        quantization: 'Q4_K_M',
        contextLength: 8192,
        ramRequired: 7.0,
        category: 'medium',
        downloadUrl: 'https://huggingface.co/models/gemma-2-9b-q4',
      ),
      AvailableModel(
        id: 'codellama-13b-q4',
        name: 'CodeLlama 13B (Q4)',
        description: 'Meta CodeLlama 13B - Specialized for code',
        sizeGB: 7.5,
        quantization: 'Q4_K_M',
        contextLength: 16384,
        ramRequired: 10.0,
        category: 'large',
        downloadUrl: 'https://huggingface.co/models/codellama-13b-q4',
      ),
      AvailableModel(
        id: 'llama-3.1-70b-q4',
        name: 'Llama 3.1 70B (Q4)',
        description: 'Meta Llama 3.1 70B - Maximum quality',
        sizeGB: 35.0,
        quantization: 'Q4_K_M',
        contextLength: 8192,
        ramRequired: 40.0,
        category: 'large',
        downloadUrl: 'https://huggingface.co/models/llama-3.1-70b-q4',
      ),
    ];
  }
  
  // TODO: Actual HTTP download requires http package or dio integration.
  // This currently creates the directory structure and metadata only.
  Future<void> downloadModel(AvailableModel model) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(p.join(dir.path, 'schatz', 'models'));
      
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }
      
      final modelDir = Directory(p.join(modelsDir.path, model.id));
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      final downloadedModel = DownloadedModel(
        id: model.id,
        name: model.name,
        size: '${model.sizeGB}GB',
        quantization: model.quantization,
        contextLength: model.contextLength,
        ramRequired: model.ramRequired,
        downloadedAt: DateTime.now(),
        filePath: p.join(modelDir.path, '${model.id}.gguf'),
      );
      
      await _saveDownloadedModel(downloadedModel);
    } catch (e) {
      debugPrint('Failed to download model: $e');
    }
  }
  
  Future<void> deleteModel(String modelId) async {
    final models = await getDownloadedModels();
    final model = models.firstWhere((m) => m.id == modelId, orElse: () => models.first);
    try {
      final file = File(model.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete model file: $e');
    }
    models.removeWhere((m) => m.id == modelId);
    await _storage.write('downloaded_models', jsonEncode(models.map((m) => m.toJson()).toList()));
  }
  
  Future<void> _saveDownloadedModel(DownloadedModel model) async {
    final models = await getDownloadedModels();
    models.add(model);
    await _storage.write('downloaded_models', jsonEncode(models.map((m) => m.toJson()).toList()));
  }
}
