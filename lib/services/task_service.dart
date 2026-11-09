import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_item.dart';

class TaskService {
  static const String appBaseUrl = 'https://gohla-alexander1985.github.io/Benotiz';
  static const String _tasksKey = 'antigravity_tasks_v1';
  static const String _groupsKey = 'antigravity_groups_v1';
  static const String _userNameKey = 'benotiz_user_name_v1';
  static final TaskService instance = TaskService._internal();

  TaskService._internal();

  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey) ?? 'Alexander';
  }

  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name.trim());
  }

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

  TaskItem? _lastDeletedTask;
  int? _lastDeletedIndex;
  List<TaskItem> _lastDeletedBatch = [];
  TaskItem? _lastStatusChangedTask;
  bool? _lastStatusPreviousState;

  bool get canUndo => _lastDeletedTask != null || _lastStatusChangedTask != null || _lastDeletedBatch.isNotEmpty;
  bool get canUndoDelete => _lastDeletedTask != null;
  TaskItem? get lastDeletedTask => _lastDeletedTask;

  Future<void> deleteTask(String taskId) async {
    await deleteTaskWithUndo(taskId);
  }

  Future<TaskItem?> deleteTaskWithUndo(String taskId) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      _lastDeletedTask = tasks[index];
      _lastDeletedIndex = index;
      tasks.removeAt(index);
      await saveTasks(tasks);
      return _lastDeletedTask;
    }
    return null;
  }

  Future<TaskItem?> undoLastDelete() async {
    if (_lastDeletedTask == null) return null;
    final taskToRestore = _lastDeletedTask!;
    final insertIndex = _lastDeletedIndex ?? 0;
    final tasks = await loadTasks();
    if (insertIndex <= tasks.length) {
      tasks.insert(insertIndex, taskToRestore);
    } else {
      tasks.add(taskToRestore);
    }
    _lastDeletedTask = null;
    _lastDeletedIndex = null;
    await saveTasks(tasks);
    return taskToRestore;
  }

  Future<int> clearCompletedTasks() async {
    final tasks = await loadTasks();
    final completed = tasks.where((t) => t.isCompleted).toList();
    if (completed.isEmpty) return 0;
    _lastDeletedBatch = completed;
    tasks.removeWhere((t) => t.isCompleted);
    await saveTasks(tasks);
    return completed.length;
  }

  Future<int> undoClearCompletedTasks() async {
    if (_lastDeletedBatch.isEmpty) return 0;
    final count = _lastDeletedBatch.length;
    final tasks = await loadTasks();
    tasks.addAll(_lastDeletedBatch);
    _lastDeletedBatch = [];
    await saveTasks(tasks);
    return count;
  }

  Future<void> toggleTaskCompleted(String taskId, {String? byUser}) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      final task = tasks[index];
      _lastStatusChangedTask = task;
      _lastStatusPreviousState = task.isCompleted;
      final newStatus = !task.isCompleted;
      final userName = byUser ?? await getUserName();

      tasks[index] = task.copyWith(
        isCompleted: newStatus,
        completedBy: newStatus ? userName : null,
        completedAt: newStatus ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );
      await saveTasks(tasks);
    }
  }

  Future<TaskItem?> undoLastStatusChange() async {
    if (_lastStatusChangedTask == null || _lastStatusPreviousState == null) return null;
    final taskId = _lastStatusChangedTask!.id;
    final task = _lastStatusChangedTask!;
    _lastStatusChangedTask = null;
    _lastStatusPreviousState = null;

    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      tasks[index] = task;
      await saveTasks(tasks);
      return task;
    }
    return null;
  }

  Future<void> setTaskCompleted(String taskId, bool isCompleted, {String? completedBy}) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      final task = tasks[index];
      final userName = completedBy ?? await getUserName();

      tasks[index] = task.copyWith(
        isCompleted: isCompleted,
        completedBy: isCompleted ? userName : null,
        completedAt: isCompleted ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );
      await saveTasks(tasks);
    }
  }

  Future<void> addCommentToTask(String taskId, TaskComment comment) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      final task = tasks[index];
      final updatedComments = List<TaskComment>.from(task.comments)..add(comment);
      tasks[index] = task.copyWith(
        comments: updatedComments,
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

  /// Encodes a task into a self-contained URL link so any recipient can open and import it
  String generateTaskShareLink(TaskItem task) {
    final jsonStr = json.encode(task.toMap());
    final bytes = utf8.encode(jsonStr);
    final base64 = base64Url.encode(bytes);
    return '$appBaseUrl/?import_task=$base64';
  }

  /// Decodes a task from the URL base64 payload
  TaskItem? decodeTaskFromPayload(String payload) {
    try {
      final clean = payload.trim().replaceAll(' ', '+');
      final bytes = base64Url.decode(clean);
      final jsonStr = utf8.decode(bytes);
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return TaskItem.fromMap(map);
    } catch (_) {
      try {
        // Fallback standard base64
        final bytes = base64.decode(payload.trim());
        final jsonStr = utf8.decode(bytes);
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return TaskItem.fromMap(map);
      } catch (_) {
        return null;
      }
    }
  }

  /// Formats the task details, comments, and real live app link for sharing
  String formatTaskShareText(TaskItem task) {
    final dueStr = task.dueDate != null
        ? '${task.dueDate!.day}.${task.dueDate!.month}.${task.dueDate!.year}'
        : 'Kein Fälligkeitsdatum';

    final link = generateTaskShareLink(task);
    final creatorStr = task.creatorName != null && task.creatorName!.isNotEmpty
        ? '• Erstellt von: ${task.creatorName}\n'
        : '';
    final statusStr = task.isCompleted
        ? '• Status: ✅ ERLEDIGT ${task.completedBy != null ? "(von ${task.completedBy})" : ""}\n'
        : '• Status: ⏳ OFFEN\n';

    String commentsStr = '';
    if (task.comments.isNotEmpty) {
      final commentsList = task.comments.map((c) => '  - ${c.author}: "${c.text}"').join('\n');
      commentsStr = '\n💬 Kommentare:\n$commentsList\n';
    }

    return '📌 BEnotiz Aufgabe: "${task.title}"\n\n'
        '$statusStr'
        '• Fällig am: $dueStr\n'
        '• Priorität: ${task.priority.toUpperCase()}\n'
        '$creatorStr'
        '${task.linkedNoteTitle != null && task.linkedNoteTitle!.isNotEmpty ? "• Entstammt Notiz: \"${task.linkedNoteTitle}\"\n" : ""}'
        '${task.assignedTo != null && task.assignedTo!.isNotEmpty ? "• Zugewiesen an: ${task.assignedTo}\n" : ""}'
        '${task.assignedGroup != null && task.assignedGroup!.isNotEmpty ? "• Gruppe: ${task.assignedGroup}\n" : ""}'
        '${task.description.isNotEmpty ? "• Details: ${task.description}\n" : ""}'
        '$commentsStr\n'
        '👉 In BEnotiz öffnen, kommentieren & erledigen:\n$link';
  }

  /// Formats urgent notification message when a task is overdue
  String formatOverdueReminderText(TaskItem task) {
    final dueStr = task.dueDate != null
        ? '${task.dueDate!.day}.${task.dueDate!.month}.${task.dueDate!.year}'
        : 'Früher';
    final link = generateTaskShareLink(task);

    return '⚠️ DRINGENDE ERINNERUNG: Frist überschritten!\n\n'
        'Die Aufgabe "${task.title}" war am $dueStr fällig und ist noch nicht erledigt!\n\n'
        '${task.description.isNotEmpty ? "Details: ${task.description}\n\n" : ""}'
        '👉 Bitte zeitnah prüfen und in BEnotiz erledigen:\n$link';
  }

  /// Formats notification message when a task has been completed by recipient
  String formatCompletedNoticeText(TaskItem task, {String? completedBy}) {
    final link = generateTaskShareLink(task);
    final by = completedBy ?? task.completedBy ?? 'Der Empfänger';

    return '✅ AUFGABE ERLEDIGT!\n\n'
        'Die Aufgabe "${task.title}" wurde soeben von $by als ERLEDIGT markiert!\n\n'
        '👉 Aktuellen Status in BEnotiz ansehen:\n$link';
  }

  /// Sends task directly via Email client (Outlook, Mail, Gmail)
  Future<bool> shareTaskViaEmail(TaskItem task) async {
    final text = formatTaskShareText(task);
    final subject = 'Aufgabe zugewiesen: ${task.title}';
    final mailtoUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': subject,
        'body': text,
      },
    );
    try {
      return await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Sends task directly via WhatsApp
  Future<bool> shareTaskViaWhatsApp(TaskItem task) async {
    final text = formatTaskShareText(task);
    final waUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');
    try {
      return await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Sends overdue reminder via Email
  Future<bool> shareOverdueReminderViaEmail(TaskItem task) async {
    final text = formatOverdueReminderText(task);
    final subject = '⚠️ Dringende Erinnerung (Überfällig): ${task.title}';
    final mailtoUri = Uri(
      scheme: 'mailto',
      queryParameters: {'subject': subject, 'body': text},
    );
    try {
      return await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Sends overdue reminder via WhatsApp
  Future<bool> shareOverdueReminderViaWhatsApp(TaskItem task) async {
    final text = formatOverdueReminderText(task);
    final waUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');
    try {
      return await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Sends task completed notice via Email
  Future<bool> shareCompletedNoticeViaEmail(TaskItem task, {String? completedBy}) async {
    final text = formatCompletedNoticeText(task, completedBy: completedBy);
    final subject = '✅ Aufgabe erledigt: ${task.title}';
    final mailtoUri = Uri(
      scheme: 'mailto',
      queryParameters: {'subject': subject, 'body': text},
    );
    try {
      return await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Sends task completed notice via WhatsApp
  Future<bool> shareCompletedNoticeViaWhatsApp(TaskItem task, {String? completedBy}) async {
    final text = formatCompletedNoticeText(task, completedBy: completedBy);
    final waUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');
    try {
      return await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Copies task formatted text and link to clipboard
  Future<void> copyTaskToClipboard(TaskItem task) async {
    final text = formatTaskShareText(task);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Sends a task to a user or group via system share dialog (WhatsApp, Email, etc.)
  Future<void> shareTask(TaskItem task) async {
    final text = formatTaskShareText(task);
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
        creatorName: 'Alexander',
      ),
      TaskItem.create(
        title: 'Urlaubsantrag einreichen & Reiseunterlagen prüfen',
        description: 'Reisepass Gültigkeit checken.',
        dueDate: now.add(const Duration(days: 3)),
        reminderDateTime: now.add(const Duration(days: 2)),
        priority: 'medium',
        assignedTo: 'Max',
        assignedGroup: 'Familie',
        creatorName: 'Alexander',
      ),
    ];
  }
}
