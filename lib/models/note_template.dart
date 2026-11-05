import 'dart:convert';
import 'package:uuid/uuid.dart';

class NoteTemplate {
  final String id;
  final String name;
  final String description;
  final String paperType; // 'blank', 'grid', 'lined', 'dots', 'cornell', 'meeting', 'planner', 'custom'
  final String defaultTitle;
  final String defaultContent;
  final String? backgroundImageBase64;
  final bool isCustom;

  NoteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.paperType,
    this.defaultTitle = '',
    this.defaultContent = '',
    this.backgroundImageBase64,
    this.isCustom = false,
  });

  factory NoteTemplate.custom({
    required String name,
    required String description,
    required String paperType,
    String defaultTitle = '',
    String defaultContent = '',
    String? backgroundImageBase64,
  }) {
    return NoteTemplate(
      id: const Uuid().v4(),
      name: name,
      description: description,
      paperType: paperType,
      defaultTitle: defaultTitle,
      defaultContent: defaultContent,
      backgroundImageBase64: backgroundImageBase64,
      isCustom: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'paperType': paperType,
      'defaultTitle': defaultTitle,
      'defaultContent': defaultContent,
      'backgroundImageBase64': backgroundImageBase64,
      'isCustom': isCustom,
    };
  }

  factory NoteTemplate.fromMap(Map<String, dynamic> map) {
    return NoteTemplate(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Vorlage',
      description: map['description'] as String? ?? '',
      paperType: map['paperType'] as String? ?? 'blank',
      defaultTitle: map['defaultTitle'] as String? ?? '',
      defaultContent: map['defaultContent'] as String? ?? '',
      backgroundImageBase64: map['backgroundImageBase64'] as String?,
      isCustom: map['isCustom'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory NoteTemplate.fromJson(String source) =>
      NoteTemplate.fromMap(json.decode(source) as Map<String, dynamic>);
}
