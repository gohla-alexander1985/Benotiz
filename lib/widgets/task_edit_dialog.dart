import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import 'task_share_dialog.dart';

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
    final today = DateTime(now.year, now.month, now.day);
    final initial = (_dueDate != null && _dueDate!.isAfter(today)) ? _dueDate! : today;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today, // Keine Daten in der Vergangenheit!
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null && mounted) {
      final isToday = pickedDate.year == now.year && pickedDate.month == now.month && pickedDate.day == now.day;
      final defaultHour = isToday ? (now.hour < 23 ? now.hour + 1 : 23) : 12;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _dueTime ?? TimeOfDay(hour: defaultHour, minute: 0),
      );

      final finalTime = pickedTime ?? TimeOfDay(hour: defaultHour, minute: 0);
      final calculatedDueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        finalTime.hour,
        finalTime.minute,
      );

      setState(() {
        _dueTime = finalTime;
        _dueDate = calculatedDueDate;
        _adjustReminderSafe(calculatedDueDate);
      });
    }
  }

  void _adjustReminderSafe(DateTime dueDate) {
    final now = DateTime.now();
    // Default reminder: 1 hour before due date if in the future
    final oneHourBefore = dueDate.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      _reminderDateTime = oneHourBefore;
    } else if (dueDate.isAfter(now)) {
      _reminderDateTime = dueDate;
    } else {
      _reminderDateTime = null;
    }
  }

  void _setPresetReminder(Duration offset) {
    if (_dueDate == null) return;
    final target = _dueDate!.subtract(offset);
    if (target.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Diese Erinnerung würde in der Vergangenheit liegen!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _reminderDateTime = target);
  }

  Future<void> _pickCustomReminder() async {
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle zuerst ein Fälligkeitsdatum.')),
      );
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: (_reminderDateTime != null && _reminderDateTime!.isAfter(today)) ? _reminderDateTime! : today,
      firstDate: today,
      lastDate: _dueDate!,
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _reminderDateTime != null
            ? TimeOfDay(hour: _reminderDateTime!.hour, minute: _reminderDateTime!.minute)
            : const TimeOfDay(hour: 9, minute: 0),
      );

      if (pickedTime != null) {
        final chosen = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (chosen.isBefore(DateTime.now())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Erinnerungen dürfen nicht in der Vergangenheit datiert werden!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _reminderDateTime = chosen;
        });
      }
    }
  }

  void _saveTask({bool andShare = false}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    if (_reminderDateTime != null && _reminderDateTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Die Erinnerung darf nicht in der Vergangenheit datiert werden!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    if (andShare && mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => TaskShareDialog(task: task),
      );
      return;
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
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm', 'de_DE');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
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

                if (widget.task?.linkedNoteTitle != null && widget.task!.linkedNoteTitle!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162A48) : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF284878) : const Color(0xFF90CAF9)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note_alt_rounded, size: 16, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Entstammt aus Notiz: "${widget.task!.linkedNoteTitle}"',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Title
                TextField(
                  controller: _titleController,
                  autofocus: widget.task == null,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'Aufgabentitel *',
                    hintText: 'Was muss getan werden?',
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Details / Beschreibung (optional)',
                  ),
                ),
                const SizedBox(height: 16),

                // Due Date & Reminder Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF182647) : const Color(0xFFF8FAFC),
                    border: Border.all(color: isDark ? const Color(0xFF283B63) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _pickDueDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                                    Text(
                                      _dueDate != null
                                          ? (_reminderDateTime != null
                                              ? '🔔 Erinnerung: ${dateFormat.format(_reminderDateTime!)}'
                                              : 'Keine Erinnerung festgelegt')
                                          : 'Tippen, um Termin & Frist zu wählen',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _reminderDateTime != null
                                            ? (isDark ? const Color(0xFF90CAF9) : Colors.blue.shade800)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_dueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Fälligkeit entfernen',
                                  onPressed: () => setState(() {
                                    _dueDate = null;
                                    _reminderDateTime = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Reminder presets (only future reminders allowed!)
                      if (_dueDate != null) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, size: 14),
                            const SizedBox(width: 6),
                            const Text(
                              'Erinnerung (nur in der Zukunft):',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_reminderDateTime != null)
                              GestureDetector(
                                onTap: () => setState(() => _reminderDateTime = null),
                                child: const Text(
                                  'Ausschalten',
                                  style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.alarm, size: 14),
                              label: const Text('Pünktlich', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                if (_dueDate!.isBefore(DateTime.now())) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('⚠️ Termin liegt in der Vergangenheit!')),
                                  );
                                  return;
                                }
                                setState(() => _reminderDateTime = _dueDate);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.timer_outlined, size: 14),
                              label: const Text('15 Min vorher', style: TextStyle(fontSize: 11)),
                              onPressed: () => _setPresetReminder(const Duration(minutes: 15)),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.timer_outlined, size: 14),
                              label: const Text('1 Std vorher', style: TextStyle(fontSize: 11)),
                              onPressed: () => _setPresetReminder(const Duration(hours: 1)),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.calendar_month_outlined, size: 14),
                              label: const Text('1 Tag vorher', style: TextStyle(fontSize: 11)),
                              onPressed: () => _setPresetReminder(const Duration(days: 1)),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.edit_calendar_outlined, size: 14),
                              label: const Text('Eigene Zeit...', style: TextStyle(fontSize: 11)),
                              onPressed: _pickCustomReminder,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Priority
                Text('Priorität', style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'low', label: Text('Niedrig')),
                      ButtonSegment(value: 'medium', label: Text('Mittel')),
                      ButtonSegment(value: 'high', label: Text('Hoch')),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (set) => setState(() => _priority = set.first),
                  ),
                ),
                const SizedBox(height: 16),

                // Assign to user
                TextField(
                  controller: _assignedToController,
                  decoration: const InputDecoration(
                    labelText: 'Zuweisen an Benutzer (Name / E-Mail)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // Group selector
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGroup,
                        decoration: const InputDecoration(
                          labelText: 'Gruppe zuweisen',
                          prefixIcon: Icon(Icons.group_outlined),
                        ),
                        dropdownColor: isDark ? const Color(0xFF162340) : Colors.white,
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

                // Responsive Action Buttons adapted to device / screen width
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 440;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _saveTask(andShare: false),
                            child: const Text('Aufgabe speichern', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Speichern & Versenden'),
                            onPressed: () => _saveTask(andShare: true),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Abbrechen'),
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Abbrechen'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text('Speichern & Teilen', maxLines: 1, overflow: TextOverflow.ellipsis),
                              onPressed: () => _saveTask(andShare: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _saveTask(andShare: false),
                              child: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
