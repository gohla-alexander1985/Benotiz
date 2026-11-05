import 'dart:convert';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final int colorValue;
  final List<String> tags;
  final bool isShared;
  final String? shareToken;
  final List<String> collaborators;
  final String permission; // 'read_only' or 'edit'
  final String? drawingData; // JSON representation of stylus strokes
  final String? drawingImageBase64; // PNG image preview for fast rendering
  final String paperType; // 'blank', 'grid', 'lined', 'dots', 'cornell', 'meeting', 'planner', 'custom'
  final String? templateImageBase64; // Uploaded custom template image

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.colorValue = 0xFFFFFFFF,
    this.tags = const [],
    this.isShared = false,
    this.shareToken,
    this.collaborators = const [],
    this.permission = 'edit',
    this.drawingData,
    this.drawingImageBase64,
    this.paperType = 'blank',
    this.templateImageBase64,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    int? colorValue,
    List<String>? tags,
    bool? isShared,
    String? shareToken,
    List<String>? collaborators,
    String? permission,
    String? drawingData,
    String? drawingImageBase64,
    bool clearDrawing = false,
    String? paperType,
    String? templateImageBase64,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      colorValue: colorValue ?? this.colorValue,
      tags: tags ?? this.tags,
      isShared: isShared ?? this.isShared,
      shareToken: shareToken ?? this.shareToken,
      collaborators: collaborators ?? this.collaborators,
      permission: permission ?? this.permission,
      drawingData: clearDrawing ? null : (drawingData ?? this.drawingData),
      drawingImageBase64: clearDrawing ? null : (drawingImageBase64 ?? this.drawingImageBase64),
      paperType: paperType ?? this.paperType,
      templateImageBase64: templateImageBase64 ?? this.templateImageBase64,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'colorValue': colorValue,
      'tags': tags,
      'isShared': isShared,
      'shareToken': shareToken,
      'collaborators': collaborators,
      'permission': permission,
      'drawingData': drawingData,
      'drawingImageBase64': drawingImageBase64,
      'paperType': paperType,
      'templateImageBase64': templateImageBase64,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      isPinned: map['isPinned'] as bool? ?? false,
      colorValue: map['colorValue'] as int? ?? 0xFFFFFFFF,
      tags: List<String>.from(map['tags'] as List? ?? []),
      isShared: map['isShared'] as bool? ?? false,
      shareToken: map['shareToken'] as String?,
      collaborators: List<String>.from(map['collaborators'] as List? ?? []),
      permission: map['permission'] as String? ?? 'edit',
      drawingData: map['drawingData'] as String?,
      drawingImageBase64: map['drawingImageBase64'] as String?,
      paperType: map['paperType'] as String? ?? 'blank',
      templateImageBase64: map['templateImageBase64'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Note.fromJson(String source) => Note.fromMap(json.decode(source) as Map<String, dynamic>);
}
