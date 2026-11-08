import 'dart:convert';
import 'package:uuid/uuid.dart';

class TaskComment {
  final String id;
  final String author;
  final String text;
  final DateTime createdAt;

  TaskComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  factory TaskComment.create({
    required String author,
    required String text,
  }) {
    return TaskComment(
      id: const Uuid().v4(),
      author: author.trim().isNotEmpty ? author.trim() : 'Empfänger',
      text: text.trim(),
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'author': author,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TaskComment.fromMap(Map<String, dynamic> map) => TaskComment(
    id: map['id'] as String? ?? const Uuid().v4(),
    author: map['author'] as String? ?? 'Empfänger',
    text: map['text'] as String? ?? '',
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class TaskItem {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final DateTime? reminderDateTime;
  final bool isCompleted;
  final String priority; // 'low', 'medium', 'high'
  final String? assignedTo; // user name or email
  final String? assignedGroup; // e.g. "Team", "Familie", "Projekt"
  final String? creatorName; // Sender / Ersteller
  final String? completedBy; // Who marked it complete
  final DateTime? completedAt;
  final List<TaskComment> comments;
  final String? linkedNoteId;
  final String? linkedNoteTitle;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskItem({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.reminderDateTime,
    this.isCompleted = false,
    this.priority = 'medium',
    this.assignedTo,
    this.assignedGroup,
    this.creatorName,
    this.completedBy,
    this.completedAt,
    this.comments = const [],
    this.linkedNoteId,
    this.linkedNoteTitle,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskItem.create({
    required String title,
    String description = '',
    DateTime? dueDate,
    DateTime? reminderDateTime,
    String priority = 'medium',
    String? assignedTo,
    String? assignedGroup,
    String? creatorName,
    String? linkedNoteId,
    String? linkedNoteTitle,
    List<TaskComment> comments = const [],
  }) {
    final now = DateTime.now();
    return TaskItem(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      reminderDateTime: reminderDateTime,
      isCompleted: false,
      priority: priority,
      assignedTo: assignedTo,
      assignedGroup: assignedGroup,
      creatorName: creatorName,
      completedBy: null,
      completedAt: null,
      comments: comments,
      linkedNoteId: linkedNoteId,
      linkedNoteTitle: linkedNoteTitle,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? reminderDateTime,
    bool? isCompleted,
    String? priority,
    String? assignedTo,
    String? assignedGroup,
    String? creatorName,
    String? completedBy,
    DateTime? completedAt,
    List<TaskComment>? comments,
    String? linkedNoteId,
    String? linkedNoteTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedGroup: assignedGroup ?? this.assignedGroup,
      creatorName: creatorName ?? this.creatorName,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      comments: comments ?? this.comments,
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
      linkedNoteTitle: linkedNoteTitle ?? this.linkedNoteTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'isCompleted': isCompleted,
      'priority': priority,
      'assignedTo': assignedTo,
      'assignedGroup': assignedGroup,
      'creatorName': creatorName,
      'completedBy': completedBy,
      'completedAt': completedAt?.toIso8601String(),
      'comments': comments.map((c) => c.toMap()).toList(),
      'linkedNoteId': linkedNoteId,
      'linkedNoteTitle': linkedNoteTitle,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    final rawComments = map['comments'] as List<dynamic>?;
    final commentsList = rawComments != null
        ? rawComments.map((c) => TaskComment.fromMap(c as Map<String, dynamic>)).toList()
        : <TaskComment>[];

    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'] as String) : null,
      reminderDateTime: map['reminderDateTime'] != null
          ? DateTime.tryParse(map['reminderDateTime'] as String)
          : null,
      isCompleted: map['isCompleted'] as bool? ?? false,
      priority: map['priority'] as String? ?? 'medium',
      assignedTo: map['assignedTo'] as String?,
      assignedGroup: map['assignedGroup'] as String?,
      creatorName: map['creatorName'] as String?,
      completedBy: map['completedBy'] as String?,
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'] as String) : null,
      comments: commentsList,
      linkedNoteId: map['linkedNoteId'] as String?,
      linkedNoteTitle: map['linkedNoteTitle'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory TaskItem.fromJson(String source) =>
      TaskItem.fromMap(json.decode(source) as Map<String, dynamic>);
}
