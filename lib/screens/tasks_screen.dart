import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/task_service.dart';
import '../widgets/be_notiz_logo.dart';
import '../widgets/task_detail_dialog.dart';
import '../widgets/task_edit_dialog.dart';
import '../widgets/task_share_dialog.dart';
import 'note_edit_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskItem> _tasks = [];
  bool _isLoading = true;
  String _selectedFilter = 'open'; // 'open', 'all', 'completed', or group name
  List<String> _groups = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tasks = await TaskService.instance.loadTasks();
    final groups = await TaskService.instance.getGroups();
    setState(() {
      _tasks = tasks;
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _toggleTask(TaskItem task) async {
    final willBeCompleted = !task.isCompleted;
    await TaskService.instance.toggleTaskCompleted(task.id);
    await _loadData();

    if (mounted) {
      if (willBeCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Aufgabe "${task.title}" erledigt!'),
            action: SnackBarAction(
              label: 'RÜCKGÄNGIG',
              textColor: Colors.amberAccent,
              onPressed: () async {
                await TaskService.instance.undoLastStatusChange();
                await _loadData();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('↩️ Aufgabe "${task.title}" wieder als offen markiert!'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    await TaskService.instance.deleteTaskWithUndo(task.id);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Aufgabe "${task.title}" gelöscht'),
          action: SnackBarAction(
            label: 'RÜCKGÄNGIG',
            textColor: Colors.amberAccent,
            onPressed: () async {
              await TaskService.instance.undoLastDelete();
              await _loadData();
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _undoLastAction() async {
    if (TaskService.instance.canUndoDelete) {
      final restored = await TaskService.instance.undoLastDelete();
      await _loadData();
      if (mounted && restored != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('↩️ Aufgabe "${restored.title}" wiederhergestellt!')),
        );
      }
    } else {
      final restored = await TaskService.instance.undoLastStatusChange();
      await _loadData();
      if (mounted && restored != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('↩️ Status von "${restored.title}" zurückgesetzt!')),
        );
      }
    }
  }

  Future<void> _clearCompletedTasks() async {
    final count = await TaskService.instance.clearCompletedTasks();
    await _loadData();
    if (mounted && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count erledigte Aufgabe(n) gelöscht'),
          action: SnackBarAction(
            label: 'RÜCKGÄNGIG',
            textColor: Colors.amberAccent,
            onPressed: () async {
              await TaskService.instance.undoClearCompletedTasks();
              await _loadData();
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _openTaskDetail(TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => TaskDetailDialog(
        task: task,
        onUpdated: () => _loadData(),
      ),
    );
  }

  void _openTaskEditor([TaskItem? task, String initialMode = 'stylus']) {
    showDialog(
      context: context,
      builder: (ctx) => TaskEditDialog(
        task: task,
        initialMode: task == null ? initialMode : 'keyboard',
        onSaved: (_) => _loadData(),
      ),
    );
  }

  void _openShareTaskDialog(TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => TaskShareDialog(task: task),
    );
  }

  Future<void> _openLinkedNote(String noteId) async {
    final notes = await StorageService.instance.loadNotes();
    final noteMatches = notes.where((n) => n.id == noteId);

    if (noteMatches.isNotEmpty && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => NoteEditScreen(note: noteMatches.first)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ursprüngliche Notiz wurde möglicherweise gelöscht.')),
      );
    }
  }

  void _showAIExtractPrompt() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Text('KI: Aufgaben extrahieren'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Füge eine E-Mail, Chatnachricht oder Notiz ein. Der KI-Agent erkennt automatisch die Aufgaben und Fristen:',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'z.B.: "Bitte bis Freitag die Quartalszahlen prüfen und Max anrufen..."',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Aufgaben generieren', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _runAIExtract(ctx, textCtrl.text.trim()),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Abbrechen'),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('Aufgaben generieren', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _runAIExtract(ctx, textCtrl.text.trim()),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAIExtract(BuildContext ctx, String text) async {
    if (text.isEmpty) return;
    Navigator.pop(ctx);

    setState(() => _isLoading = true);
    final extracted = await AIService.instance.extractTasksFromText('Text-Eingabe', text);
    await TaskService.instance.addTasks(extracted);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ ${extracted.length} Aufgabe(n) von der KI erkannt und hinzugefügt!'),
          action: SnackBarAction(
            label: 'RÜCKGÄNGIG',
            textColor: Colors.amberAccent,
            onPressed: () async {
              for (final t in extracted) {
                await TaskService.instance.deleteTask(t.id);
              }
              await _loadData();
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  List<TaskItem> get _filteredTasks {
    return _tasks.where((task) {
      if (_selectedFilter == 'open' && task.isCompleted) return false;
      if (_selectedFilter == 'completed' && !task.isCompleted) return false;
      if (_selectedFilter != 'open' && _selectedFilter != 'all' && _selectedFilter != 'completed') {
        if (task.assignedGroup != _selectedFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = task.title.toLowerCase().contains(query);
        final matchesDesc = task.description.toLowerCase().contains(query);
        final matchesAssigned = task.assignedTo?.toLowerCase().contains(query) ?? false;
        final matchesGroup = task.assignedGroup?.toLowerCase().contains(query) ?? false;
        final matchesNote = task.linkedNoteTitle?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesDesc && !matchesAssigned && !matchesGroup && !matchesNote) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredTasks;
    final dateFormat = DateFormat('dd. MMM, HH:mm', 'de_DE');
    final openCount = _tasks.where((t) => !t.isCompleted).length;
    final completedCount = _tasks.where((t) => t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            BENotizLogo(size: 32),
            SizedBox(width: 12),
            Text(
              'Aufgaben',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          // Undo button if there is any action to undo
          if (TaskService.instance.canUndo)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Letzte Aktion rückgängig machen (Undo)',
              onPressed: _undoLastAction,
            ),
          // Clear completed tasks button
          if (_selectedFilter == 'completed' && completedCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Alle erledigten Aufgaben löschen (Delete)',
              onPressed: _clearCompletedTasks,
            ),
          // AI Extraction button
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Aufgaben mit KI aus Text generieren',
            onPressed: _showAIExtractPrompt,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Overdue warning banner
                Builder(
                  builder: (context) {
                    final overdueTasks = _tasks.where((t) => t.isOverdue).toList();
                    if (overdueTasks.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.red.withAlpha(40) : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '⚠️ ${overdueTasks.length} überfällige Aufgabe${overdueTasks.length > 1 ? "n" : ""}!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.red.shade200 : Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Die Frist ist abgelaufen. Klicke auf eine Aufgabe, um eine Mahnung/Erinnerung zu senden.',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.red.shade300 : Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // CRUD Action Bar (Stylus Task, Text Task, AI, Undo) - Responsive full-width
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Row(
                    children: [
                      // Stylus task (Lenovo Pen / Handschrift -> Druckschrift)
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.draw_rounded, size: 18),
                          label: const Text('✍️ Stift-Aufgabe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => _openTaskEditor(null, 'stylus'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Text task directly
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_task_rounded, size: 16),
                          label: const Text('+ Text', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                          onPressed: () => _openTaskEditor(null, 'keyboard'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // AI Recognition
                      Tooltip(
                        message: 'Aufgaben mit KI aus Text generieren',
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          onPressed: _showAIExtractPrompt,
                        ),
                      ),
                      if (TaskService.instance.canUndo) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Rückgängig machen (Undo)',
                          child: IconButton.filledTonal(
                            icon: const Icon(Icons.undo_rounded, size: 20),
                            onPressed: _undoLastAction,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Search Bar (Read / Filter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Aufgaben durchsuchen...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),

                // Filter chips row (Read)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('Offen ($openCount)'),
                        selected: _selectedFilter == 'open',
                        onSelected: (_) => setState(() => _selectedFilter = 'open'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('Alle (${_tasks.length})'),
                        selected: _selectedFilter == 'all',
                        onSelected: (_) => setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('Erledigt ($completedCount)'),
                        selected: _selectedFilter == 'completed',
                        onSelected: (_) => setState(() => _selectedFilter = 'completed'),
                      ),
                      ..._groups.map((group) => Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: FilterChip(
                              avatar: const Icon(Icons.group_outlined, size: 14),
                              label: Text(group),
                              selected: _selectedFilter == group,
                              onSelected: (_) => setState(() => _selectedFilter = group),
                            ),
                          )),
                    ],
                  ),
                ),

                // Task list (Read & CRUD actions on each item)
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt_rounded, size: 64, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilter == 'open'
                                    ? 'Alles erledigt! Keine offenen Aufgaben.'
                                    : 'Keine Aufgaben gefunden',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 85),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final task = filtered[idx];
                            final isOverdue = task.isOverdue;
                            final priorityColor = _getPriorityColor(task.priority);

                            return Card(
                              elevation: 1,
                              color: isDark ? const Color(0xFF131D38) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isOverdue
                                      ? Colors.red.withAlpha(isDark ? 180 : 100)
                                      : (isDark ? const Color(0xFF283B63) : Colors.black.withAlpha(15)),
                                  width: isOverdue ? 1.5 : 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openTaskDetail(task),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Checkbox (Toggle completed)
                                      Checkbox(
                                        value: task.isCompleted,
                                        activeColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6)),
                                        onChanged: (_) => _toggleTask(task),
                                      ),
                                      const SizedBox(width: 4),

                                      // Content (Read)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                decoration: task.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: task.isCompleted
                                                    ? Colors.grey
                                                    : theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            if (task.description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                task.description,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 8),

                                            // Metadata Badges (Due, Group, Assignee, Priority)
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                // Priority badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: priorityColor.withAlpha(25),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    task.priority.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: priorityColor,
                                                    ),
                                                  ),
                                                ),

                                                // Due date badge
                                                if (task.dueDate != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isOverdue
                                                          ? Colors.red.withAlpha(isDark ? 50 : 30)
                                                          : Colors.blue.withAlpha(isDark ? 50 : 25),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today_rounded,
                                                          size: 11,
                                                          color: isOverdue
                                                              ? Colors.red
                                                              : (isDark ? const Color(0xFF90CAF9) : Colors.blue.shade800),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          dateFormat.format(task.dueDate!),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: isOverdue
                                                                ? Colors.red
                                                                : (isDark ? const Color(0xFF90CAF9) : Colors.blue.shade800),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // Reminder badge
                                                if (task.reminderDateTime != null)
                                                  Icon(
                                                    Icons.notifications_active_outlined,
                                                    size: 14,
                                                    color: isDark ? const Color(0xFF90CAF9) : Colors.blue.shade700,
                                                  ),

                                                // Group badge
                                                if (task.assignedGroup != null &&
                                                    task.assignedGroup!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple.withAlpha(25),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.group_outlined,
                                                            size: 11, color: Colors.purple),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          task.assignedGroup!,
                                                          style: const TextStyle(
                                                              fontSize: 11, color: Colors.purple),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // Assignee badge
                                                if (task.assignedTo != null &&
                                                    task.assignedTo!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.teal.withAlpha(25),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.person_outline,
                                                            size: 11, color: Colors.teal),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          task.assignedTo!,
                                                          style: const TextStyle(
                                                              fontSize: 11, color: Colors.teal),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // Originating Note Badge
                                                if (task.linkedNoteTitle != null &&
                                                    task.linkedNoteTitle!.isNotEmpty)
                                                  InkWell(
                                                    onTap: task.linkedNoteId != null
                                                        ? () => _openLinkedNote(task.linkedNoteId!)
                                                        : null,
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF162A48) : const Color(0xFFE3F2FD),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                            color: isDark ? const Color(0xFF284878) : const Color(0xFFBBDEFB)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.note_alt_rounded,
                                                              size: 11, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Notiz: ${task.linkedNoteTitle}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
                                                            ),
                                                          ),
                                                          if (task.linkedNoteId != null) ...[
                                                            const SizedBox(width: 2),
                                                            Icon(Icons.arrow_forward_rounded,
                                                                size: 10, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),

                                                // Comments count badge
                                                if (task.comments.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withAlpha(25),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.chat_bubble_outline_rounded,
                                                            size: 11, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${task.comments.length} Kommentar(e)',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // Completed by badge
                                                if (task.isCompleted && task.completedBy != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withAlpha(25),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.done_all_rounded,
                                                            size: 11, color: Colors.green),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Erledigt von: ${task.completedBy}',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.green,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Actions: Overdue, Undo, Edit, Share, Delete
                                      if (isOverdue)
                                        IconButton(
                                          icon: const Icon(Icons.alarm_on_rounded, size: 18, color: Colors.red),
                                          tooltip: 'Frist-Mahnung versenden',
                                          onPressed: () => _openShareTaskDialog(task),
                                        ),
                                      // Undo for completed task
                                      if (task.isCompleted)
                                        IconButton(
                                          icon: const Icon(Icons.undo_rounded, size: 18, color: Colors.blue),
                                          tooltip: 'Als offen markieren (Rückgängig)',
                                          onPressed: () => _toggleTask(task),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Bearbeiten',
                                        onPressed: () => _openTaskEditor(task),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share_rounded, size: 18),
                                        tooltip: 'Aufgabe teilen / versenden',
                                        onPressed: () => _openShareTaskDialog(task),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                        color: Colors.red.shade400,
                                        tooltip: 'Löschen (Delete)',
                                        onPressed: () => _deleteTask(task),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (screenWidth < 600) {
            return Container(
              width: screenWidth - 32,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: FloatingActionButton.extended(
                heroTag: 'fab_tasks_new_task',
                onPressed: () => _openTaskEditor(),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Neue Aufgabe erstellen', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          } else {
            return FloatingActionButton.extended(
              heroTag: 'fab_tasks_new_task',
              onPressed: () => _openTaskEditor(),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Neue Aufgabe'),
            );
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
