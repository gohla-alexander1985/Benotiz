import 'dart:convert';
import 'package:uuid/uuid.dart';

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
  final String? linkedNoteId;
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
    this.linkedNoteId,
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
    String? linkedNoteId,
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
      linkedNoteId: linkedNoteId,
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
    String? linkedNoteId,
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
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
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
      'linkedNoteId': linkedNoteId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
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
      linkedNoteId: map['linkedNoteId'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory TaskItem.fromJson(String source) =>
      TaskItem.fromMap(json.decode(source) as Map<String, dynamic>);
}
