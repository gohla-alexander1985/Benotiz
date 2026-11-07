import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/task_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
    await TaskService.instance.toggleTaskCompleted(task.id);
    await _loadData();
  }

  Future<void> _deleteTask(TaskItem task) async {
    await TaskService.instance.deleteTask(task.id);
    await _loadData();
  }

  void _openTaskEditor([TaskItem? task]) {
    showDialog(
      context: context,
      builder: (ctx) => TaskEditDialog(
        task: task,
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 10),
            Text('KI: Aufgaben extrahieren'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Füge eine E-Mail, Chatnachricht oder Notiz ein. Der KI-Agent erkennt automatisch die Aufgaben und Fristen:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'z.B.: "Bitte bis Freitag die Quartalszahlen prüfen und Max anrufen..."',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Aufgaben generieren'),
            onPressed: () async {
              final text = textCtrl.text.trim();
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
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  List<TaskItem> get _filteredTasks {
    return _tasks.where((task) {
      if (_selectedFilter == 'open') return !task.isCompleted;
      if (_selectedFilter == 'completed') return task.isCompleted;
      if (_selectedFilter == 'all') return true;
      // Filter by group
      return task.assignedGroup == _selectedFilter;
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
    final filtered = _filteredTasks;
    final dateFormat = DateFormat('dd. MMM, HH:mm', 'de_DE');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Aufgaben',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
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
                // Filter chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Offen'),
                        selected: _selectedFilter == 'open',
                        onSelected: (_) => setState(() => _selectedFilter = 'open'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Alle'),
                        selected: _selectedFilter == 'all',
                        onSelected: (_) => setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Erledigt'),
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

                // Task list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt_rounded, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilter == 'open'
                                    ? 'Alles erledigt! Keine offenen Aufgaben.'
                                    : 'Keine Aufgaben gefunden',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final task = filtered[idx];
                            final isOverdue = task.isOverdue;
                            final priorityColor = _getPriorityColor(task.priority);

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isOverdue
                                      ? Colors.red.withAlpha(100)
                                      : Colors.black.withAlpha(15),
                                  width: isOverdue ? 1.5 : 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openTaskEditor(task),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Checkbox
                                      Checkbox(
                                        value: task.isCompleted,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6)),
                                        onChanged: (_) => _toggleTask(task),
                                      ),
                                      const SizedBox(width: 4),

                                      // Content
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
                                                  color: Colors.grey.shade600,
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
                                                          ? Colors.red.withAlpha(30)
                                                          : Colors.blue.withAlpha(25),
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
                                                              : Colors.blue.shade800,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          dateFormat.format(task.dueDate!),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: isOverdue
                                                                ? Colors.red
                                                                : Colors.blue.shade800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // Reminder badge
                                                if (task.reminderDateTime != null)
                                                  Icon(Icons.notifications_active_outlined,
                                                      size: 14, color: Colors.blue.shade700),

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
                                                        color: const Color(0xFFE3F2FD),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                            color: const Color(0xFFBBDEFB)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.note_alt_rounded,
                                                              size: 11, color: Color(0xFF1565C0)),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Notiz: ${task.linkedNoteTitle}',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF1565C0),
                                                            ),
                                                          ),
                                                          if (task.linkedNoteId != null) ...[
                                                            const SizedBox(width: 2),
                                                            const Icon(Icons.arrow_forward_rounded,
                                                                size: 10, color: Color(0xFF1565C0)),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Actions: Share & Delete
                                      IconButton(
                                        icon: const Icon(Icons.share_rounded, size: 18),
                                        tooltip: 'Aufgabe an Nutzer oder Gruppe versenden',
                                        onPressed: () => _openShareTaskDialog(task),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                        color: Colors.red.shade400,
                                        tooltip: 'Löschen',
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_tasks_new_task',
        onPressed: () => _openTaskEditor(),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Neue Aufgabe'),
      ),
    );
  }
}
