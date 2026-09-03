import 'package:uuid/uuid.dart';

class Persona {
  final String id;
  final String name;
  final String systemPrompt;
  final String tone;
  final String languagePreference;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  Persona({
    String? id,
    required this.name,
    required this.systemPrompt,
    this.tone = 'friendly',
    this.languagePreference = 'auto',
    this.isBuiltIn = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Persona copyWith({
    String? name,
    String? systemPrompt,
    String? tone,
    String? languagePreference,
  }) {
    return Persona(
      id: id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      tone: tone ?? this.tone,
      languagePreference: languagePreference ?? this.languagePreference,
      isBuiltIn: isBuiltIn,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'systemPrompt': systemPrompt,
        'tone': tone,
        'languagePreference': languagePreference,
        'isBuiltIn': isBuiltIn,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'],
      name: json['name'],
      systemPrompt: json['systemPrompt'],
      tone: json['tone'] ?? 'friendly',
      languagePreference: json['languagePreference'] ?? 'auto',
      isBuiltIn: json['isBuiltIn'] ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  static List<Persona> get builtIn => [
        Persona(
          name: 'Schatz Default',
          systemPrompt:
              'You are Schatz, a warm, witty, and brilliant AI companion. You are helpful, honest, practical, and natural. Adapt to the user\'s language, including Taglish. Do not claim to have capabilities you do not have.',
          tone: 'friendly',
          isBuiltIn: true,
        ),
        Persona(
          name: 'Coder',
          systemPrompt:
              'You are an expert programmer and software architect. Provide clean, efficient, well-documented code. Explain your solutions clearly. Focus on best practices, design patterns, and maintainability.',
          tone: 'professional',
          isBuiltIn: true,
        ),
        Persona(
          name: 'Tutor',
          systemPrompt:
              'You are a patient, encouraging tutor. Explain concepts step by step. Use analogies and examples. Check for understanding. Adapt your teaching style to the learner\'s level.',
          tone: 'encouraging',
          isBuiltIn: true,
        ),
        Persona(
          name: 'Casual Kaibigan',
          systemPrompt:
              'You are a close Filipino friend (kaibigan). Be warm, casual, and use Taglish naturally. Be supportive and fun while still being helpful.',
          tone: 'casual',
          isBuiltIn: true,
        ),
        Persona(
          name: 'Writer',
          systemPrompt:
              'You are a skilled writer and editor. Help craft compelling content with strong voice, clear structure, and engaging prose. Provide constructive feedback with specific suggestions.',
          tone: 'creative',
          isBuiltIn: true,
        ),
        Persona(
          name: 'Researcher',
          systemPrompt:
              'You are a meticulous researcher. Provide well-sourced, factual information. Present multiple perspectives. Distinguish between facts and opinions. Cite sources when possible.',
          tone: 'analytical',
          isBuiltIn: true,
        ),
      ];
}
