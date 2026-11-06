import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';

class ChecklistToTasksDialog extends StatefulWidget {
  final String noteContent;
  final String noteTitle;
  final String noteId;

  const ChecklistToTasksDialog({
    super.key,
    required this.noteContent,
    required this.noteTitle,
    required this.noteId,
  });

  @override
  State<ChecklistToTasksDialog> createState() => _ChecklistToTasksDialogState();
}

class _ChecklistToTasksDialogState extends State<ChecklistToTasksDialog> {
  final List<String> _foundItems = [];
  final Set<String> _selectedItems = {};
  DateTime? _dueDate;
  String? _assignedUser;
  String? _selectedGroup;
  List<String> _availableGroups = [];
  bool _shareDirectly = false;

  @override
  void initState() {
    super.initState();
    _parseChecklistItems();
    _loadGroups();
  }

  void _parseChecklistItems() {
    final lines = widget.noteContent.split('\n');
    final regExp = RegExp(r'^(\[[ xX]\]|[-*•□]\s*\[[ xX]\])\s*(.+)$');

    for (final line in lines) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final text = match.group(2)?.trim();
        if (text != null && text.isNotEmpty) {
          _foundItems.add(text);
          _selectedItems.add(text);
        }
      }
    }
  }

  Future<void> _loadGroups() async {
    final groups = await TaskService.instance.getGroups();
    setState(() {
      _availableGroups = groups;
      if (groups.isNotEmpty) _selectedGroup = groups.first;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _exportTasks() async {
    if (_selectedItems.isEmpty) return;

    final tasksToCreate = _selectedItems.map((title) {
      return TaskItem.create(
        title: title,
        dueDate: _dueDate,
        reminderDateTime: _dueDate?.subtract(const Duration(hours: 2)),
        assignedTo: _assignedUser,
        assignedGroup: _selectedGroup,
        linkedNoteId: widget.noteId,
        linkedNoteTitle: widget.noteTitle.isNotEmpty ? widget.noteTitle : 'Unbenannte Notiz',
      );
    }).toList();

    await TaskService.instance.addTasks(tasksToCreate);

    if (_shareDirectly && tasksToCreate.isNotEmpty) {
      final taskListStr = tasksToCreate.map((t) => '• ${t.title}').join('\n');
      final groupStr = _selectedGroup != null ? "Gruppe: $_selectedGroup\n" : "";
      final summary = '📌 Neue Aufgaben aus BEnotiz ("${widget.noteTitle}"):\n\n'
          '$taskListStr\n\n'
          '$groupStr'
          'In BEnotiz ansehen: https://benotiz.app/tasks';

      await TaskService.instance.shareTask(TaskItem.create(
        title: 'Aufgabenpaket aus "${widget.noteTitle}"',
        description: summary,
        assignedGroup: _selectedGroup,
        assignedTo: _assignedUser,
        dueDate: _dueDate,
      ));
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${tasksToCreate.length} Aufgabe(n) erfolgreich in die Aufgabenliste übertragen!'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF00796B), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Checkliste als Aufgaben übernehmen',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Aufgaben terminieren & an Benutzer/Gruppen versenden',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (_foundItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Keine Checklisten-Einträge (z.B. "[ ] Aufgabe") im Text gefunden.\n'
                      'Füge Checklisten mit dem [☑️]-Symbol in der Leiste ein.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  )
                else ...[
                  Text(
                    'Erkannte Einträge (${_selectedItems.length} ausgewählt):',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _foundItems.length,
                      itemBuilder: (ctx, idx) {
                        final item = _foundItems[idx];
                        final isSelected = _selectedItems.contains(item);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(item, style: const TextStyle(fontSize: 14)),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedItems.add(item);
                              } else {
                                _selectedItems.remove(item);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Due Date
                  InkWell(
                    onTap: _pickDueDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF1565C0)),
                          const SizedBox(width: 10),
                          Text(
                            _dueDate != null
                                ? 'Fällig am: ${dateFormat.format(_dueDate!)}'
                                : 'Fälligkeitsdatum festlegen (optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _dueDate != null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Group Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGroup,
                    decoration: InputDecoration(
                      labelText: 'Gruppe zuweisen',
                      prefixIcon: const Icon(Icons.group_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _availableGroups.map((g) {
                      return DropdownMenuItem(value: g, child: Text(g));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedGroup = val),
                  ),
                  const SizedBox(height: 12),

                  // User Assignment
                  TextField(
                    onChanged: (val) => _assignedUser = val.trim(),
                    decoration: InputDecoration(
                      labelText: 'Zuweisen an Benutzer (Name / E-Mail)',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Share directly checkbox
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Direkt per Messenger / E-Mail versenden'),
                    value: _shareDirectly,
                    onChanged: (val) => setState(() => _shareDirectly = val ?? false),
                  ),
                ],

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                    if (_foundItems.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Aufgaben erstellen'),
                        onPressed: _selectedItems.isEmpty ? null : _exportTasks,
                      ),
                    ],
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
