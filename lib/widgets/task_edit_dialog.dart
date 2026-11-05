import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';

class TaskEditDialog extends StatefulWidget {
  final TaskItem? task;
  final String? initialTitle;
  final ValueChanged<TaskItem> onSaved;

  const TaskEditDialog({
    super.key,
    this.task,
    this.initialTitle,
    required this.onSaved,
  });

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _assignedToController;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  DateTime? _reminderDateTime;
  String _priority = 'medium';
  String? _selectedGroup;
  List<String> _availableGroups = [];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? widget.initialTitle ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _assignedToController = TextEditingController(text: t?.assignedTo ?? '');
    _dueDate = t?.dueDate;
    if (_dueDate != null) {
      _dueTime = TimeOfDay(hour: _dueDate!.hour, minute: _dueDate!.minute);
    }
    _reminderDateTime = t?.reminderDateTime;
    _priority = t?.priority ?? 'medium';
    _selectedGroup = t?.assignedGroup;

    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await TaskService.instance.getGroups();
    setState(() {
      _availableGroups = groups;
      if (_selectedGroup == null && groups.isNotEmpty) {
        _selectedGroup = groups.first;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _assignedToController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _dueTime ?? const TimeOfDay(hour: 12, minute: 0),
      );

      setState(() {
        _dueTime = pickedTime ?? const TimeOfDay(hour: 12, minute: 0);
        _dueDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _dueTime!.hour,
          _dueTime!.minute,
        );
        // Default reminder: 1 hour before due date
        _reminderDateTime = _dueDate!.subtract(const Duration(hours: 1));
      });
    }
  }

  void _saveTask({bool andShare = false}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final task = (widget.task ?? TaskItem.create(title: title)).copyWith(
      title: title,
      description: _descController.text.trim(),
      dueDate: _dueDate,
      reminderDateTime: _reminderDateTime,
      priority: _priority,
      assignedTo: _assignedToController.text.trim().isNotEmpty
          ? _assignedToController.text.trim()
          : null,
      assignedGroup: _selectedGroup,
      updatedAt: DateTime.now(),
    );

    await TaskService.instance.saveOrUpdateTask(task);
    widget.onSaved(task);

    if (andShare) {
      await TaskService.instance.shareTask(task);
    }

    if (mounted) Navigator.pop(context);
  }

  void _addNewGroupPrompt() {
    final groupCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neue Gruppe anlegen'),
        content: TextField(
          controller: groupCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'z.B. Marketing, Sportverein'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final name = groupCtrl.text.trim();
              if (name.isNotEmpty) {
                await TaskService.instance.addGroup(name);
                await _loadGroups();
                setState(() => _selectedGroup = name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm', 'de_DE');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.check_circle_outline_rounded,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      widget.task == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                TextField(
                  controller: _titleController,
                  autofocus: widget.task == null,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Aufgabentitel *',
                    hintText: 'Was muss getan werden?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Details / Beschreibung (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Due Date & Reminder Button
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dueDate != null
                                    ? 'Fällig: ${dateFormat.format(_dueDate!)}'
                                    : 'Fälligkeitsdatum festlegen',
                                style: TextStyle(
                                  fontWeight: _dueDate != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (_reminderDateTime != null)
                                Text(
                                  '🔔 Erinnerung: ${dateFormat.format(_reminderDateTime!)}',
                                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                ),
                            ],
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _dueDate = null;
                              _reminderDateTime = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Priority
                Text('Priorität', style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('Niedrig')),
                    ButtonSegment(value: 'medium', label: Text('Mittel')),
                    ButtonSegment(value: 'high', label: Text('Hoch')),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (set) => setState(() => _priority = set.first),
                ),
                const SizedBox(height: 16),

                // Assign to user
                TextField(
                  controller: _assignedToController,
                  decoration: InputDecoration(
                    labelText: 'Zuweisen an Benutzer (Name / E-Mail)',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Group selector
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGroup,
                        decoration: InputDecoration(
                          labelText: 'Gruppe zuweisen',
                          prefixIcon: const Icon(Icons.group_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _availableGroups.map((g) {
                          return DropdownMenuItem(value: g, child: Text(g));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedGroup = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      tooltip: 'Neue Gruppe erstellen',
                      onPressed: _addNewGroupPrompt,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Speichern & Versenden'),
                      onPressed: () => _saveTask(andShare: true),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _saveTask(andShare: false),
                      child: const Text('Speichern'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
