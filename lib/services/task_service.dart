import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_item.dart';

class TaskService {
  static const String _tasksKey = 'antigravity_tasks_v1';
  static const String _groupsKey = 'antigravity_groups_v1';
  static final TaskService instance = TaskService._internal();

  TaskService._internal();

  Future<List<TaskItem>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString(_tasksKey);

    if (tasksJson == null || tasksJson.isEmpty) {
      final sampleTasks = _createSampleTasks();
      await saveTasks(sampleTasks);
      return sampleTasks;
    }

    try {
      final List<dynamic> decoded = json.decode(tasksJson);
      return decoded.map((item) => TaskItem.fromMap(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(tasks.map((t) => t.toMap()).toList());
    await prefs.setString(_tasksKey, encoded);
  }

  Future<void> saveOrUpdateTask(TaskItem task) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      tasks[index] = task;
    } else {
      tasks.insert(0, task);
    }
    await saveTasks(tasks);
  }

  Future<void> addTasks(List<TaskItem> newTasks) async {
    final tasks = await loadTasks();
    tasks.insertAll(0, newTasks);
    await saveTasks(tasks);
  }

  Future<void> deleteTask(String taskId) async {
    final tasks = await loadTasks();
    tasks.removeWhere((t) => t.id == taskId);
    await saveTasks(tasks);
  }

  Future<void> toggleTaskCompleted(String taskId) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      final task = tasks[index];
      tasks[index] = task.copyWith(
        isCompleted: !task.isCompleted,
        updatedAt: DateTime.now(),
      );
      await saveTasks(tasks);
    }
  }

  Future<List<String>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final groups = prefs.getStringList(_groupsKey);
    if (groups == null || groups.isEmpty) {
      final defaultGroups = ['Projekt Team', 'Familie', 'Arbeit', 'Privat'];
      await prefs.setStringList(_groupsKey, defaultGroups);
      return defaultGroups;
    }
    return groups;
  }

  Future<void> addGroup(String groupName) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await getGroups();
    if (!groups.contains(groupName.trim()) && groupName.trim().isNotEmpty) {
      groups.add(groupName.trim());
      await prefs.setStringList(_groupsKey, groups);
    }
  }

  /// Sends a task to a user or group via system share dialog (WhatsApp, Email, etc.)
  Future<void> shareTask(TaskItem task) async {
    final dueStr = task.dueDate != null
        ? '${task.dueDate!.day}.${task.dueDate!.month}.${task.dueDate!.year}'
        : 'Kein Fälligkeitsdatum';

    final text = '📌 Neue Aufgabe: "${task.title}"\n\n'
        '• Fällig am: $dueStr\n'
        '• Priorität: ${task.priority.toUpperCase()}\n'
        '${task.linkedNoteTitle != null && task.linkedNoteTitle!.isNotEmpty ? "• Entstammt Notiz: \"${task.linkedNoteTitle}\"\n" : ""}'
        '${task.assignedTo != null && task.assignedTo!.isNotEmpty ? "• Zugewiesen an: ${task.assignedTo}\n" : ""}'
        '${task.assignedGroup != null && task.assignedGroup!.isNotEmpty ? "• Gruppe: ${task.assignedGroup}\n" : ""}'
        '${task.description.isNotEmpty ? "• Details: ${task.description}\n" : ""}\n'
        'In BEnotiz öffnen: https://benotiz.app/task/${task.id}';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Aufgabe zugewiesen: ${task.title}',
      ),
    );
  }

  List<TaskItem> _createSampleTasks() {
    final now = DateTime.now();
    return [
      TaskItem.create(
        title: 'App-Dokumentation & KI-Funktionen testen',
        description: 'Audio-Aufnahme und Text-Analyse mit Beispielen ausprobieren.',
        dueDate: now.add(const Duration(days: 1)),
        reminderDateTime: now.add(const Duration(hours: 12)),
        priority: 'high',
        assignedTo: 'Du',
        assignedGroup: 'Projekt Team',
      ),
      TaskItem.create(
        title: 'Urlaubsantrag einreichen & Reiseunterlagen prüfen',
        description: 'Reisepass Gültigkeit checken.',
        dueDate: now.add(const Duration(days: 3)),
        reminderDateTime: now.add(const Duration(days: 2)),
        priority: 'medium',
        assignedTo: 'Max',
        assignedGroup: 'Familie',
      ),
    ];
  }
}
