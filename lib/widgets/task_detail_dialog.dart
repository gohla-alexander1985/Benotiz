import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import 'task_edit_dialog.dart';
import 'task_share_dialog.dart';

class TaskDetailDialog extends StatefulWidget {
  final TaskItem task;
  final VoidCallback onUpdated;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.onUpdated,
  });

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  late TaskItem _task;
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _authorCtrl = TextEditingController();
  bool _isAddingComment = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _initAuthor();
  }

  Future<void> _initAuthor() async {
    final name = await TaskService.instance.getUserName();
    _authorCtrl.text = name;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleCompleted() async {
    final newStatus = !_task.isCompleted;
    final userName = _authorCtrl.text.trim().isNotEmpty ? _authorCtrl.text.trim() : 'Empfänger';

    await TaskService.instance.setTaskCompleted(_task.id, newStatus, completedBy: userName);
    setState(() {
      _task = _task.copyWith(
        isCompleted: newStatus,
        completedBy: newStatus ? userName : null,
        completedAt: newStatus ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );
    });
    widget.onUpdated();

    if (newStatus && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Aufgabe erledigt von $userName!'),
          action: SnackBarAction(
            label: 'Absender benachrichtigen',
            onPressed: () {
              TaskService.instance.shareCompletedNoticeViaWhatsApp(_task);
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final author = _authorCtrl.text.trim().isNotEmpty ? _authorCtrl.text.trim() : 'Empfänger';
    final comment = TaskComment.create(author: author, text: text);

    setState(() => _isAddingComment = true);
    await TaskService.instance.addCommentToTask(_task.id, comment);

    setState(() {
      _task = _task.copyWith(
        comments: [..._task.comments, comment],
        updatedAt: DateTime.now(),
      );
      _commentCtrl.clear();
      _isAddingComment = false;
    });

    widget.onUpdated();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('💬 Kommentar erfolgreich hinzugefügt!'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');
    final timeFormat = DateFormat('dd.MM.yyyy HH:mm', 'de_DE');

    final dueStr = _task.dueDate != null ? dateFormat.format(_task.dueDate!) : 'Kein Fälligkeitsdatum';
    final isOverdue = _task.isOverdue;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _task.isCompleted
                          ? (isDark ? Colors.green.withAlpha(40) : Colors.green.shade50)
                          : (isDark ? const Color(0xFF162A48) : const Color(0xFFE3F2FD)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _task.isCompleted
                            ? (isDark ? Colors.green.shade600 : Colors.green.shade300)
                            : (isDark ? const Color(0xFF284878) : const Color(0xFFBBDEFB)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _task.isCompleted ? Icons.check_circle : Icons.pending_actions_rounded,
                          size: 16,
                          color: _task.isCompleted ? Colors.green : (isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _task.isCompleted ? 'ERLEDIGT' : 'OFFEN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _task.isCompleted ? Colors.green : (isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Aufgabe bearbeiten',
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => TaskEditDialog(
                          task: _task,
                          onSaved: (_) => widget.onUpdated(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 20),
                    tooltip: 'Aufgabe teilen / zurücksenden',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => TaskShareDialog(task: _task),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _task.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: _task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Overdue alert banner if applicable
                      if (isOverdue) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.red.withAlpha(40) : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Frist überschritten! War fällig am $dueStr.',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11),
                                ),
                                icon: const Icon(Icons.alarm, size: 14),
                                label: const Text('Mahnung senden'),
                                onPressed: () {
                                  TaskService.instance.shareOverdueReminderViaWhatsApp(_task);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Description
                      if (_task.description.isNotEmpty) ...[
                        Text(
                          _task.description,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isDark ? const Color(0xFFE2EDF8) : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Badges Wrap
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildBadge(
                            icon: Icons.calendar_today_rounded,
                            label: 'Fällig: $dueStr',
                            color: isOverdue ? Colors.red : const Color(0xFF1565C0),
                          ),
                          _buildBadge(
                            icon: Icons.flag_rounded,
                            label: 'Prio: ${_task.priority.toUpperCase()}',
                            color: _task.priority == 'high' ? Colors.red : Colors.orange.shade800,
                          ),
                          if (_task.creatorName != null && _task.creatorName!.isNotEmpty)
                            _buildBadge(
                              icon: Icons.person_outline_rounded,
                              label: 'Von: ${_task.creatorName}',
                              color: Colors.indigo,
                            ),
                          if (_task.assignedTo != null && _task.assignedTo!.isNotEmpty)
                            _buildBadge(
                              icon: Icons.assignment_ind_rounded,
                              label: 'An: ${_task.assignedTo}',
                              color: Colors.teal,
                            ),
                          if (_task.assignedGroup != null && _task.assignedGroup!.isNotEmpty)
                            _buildBadge(
                              icon: Icons.group_outlined,
                              label: _task.assignedGroup!,
                              color: Colors.purple,
                            ),
                          if (_task.linkedNoteTitle != null && _task.linkedNoteTitle!.isNotEmpty)
                            _buildBadge(
                              icon: Icons.note_alt_rounded,
                              label: 'Notiz: ${_task.linkedNoteTitle}',
                              color: isDark ? const Color(0xFF90CAF9) : Colors.blue.shade900,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Toggle Completed Action Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _task.isCompleted
                              ? (isDark ? Colors.green.withAlpha(30) : Colors.green.shade50)
                              : (isDark ? const Color(0xFF182647) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _task.isCompleted
                                ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
                                : (isDark ? const Color(0xFF283B63) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _task.isCompleted,
                              activeColor: Colors.green,
                              onChanged: (_) => _toggleCompleted(),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _task.isCompleted ? 'Als erledigt markiert' : 'Aufgabe als erledigt markieren',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (_task.isCompleted && _task.completedBy != null)
                                    Text(
                                      'Erledigt von: ${_task.completedBy} am ${timeFormat.format(_task.completedAt ?? DateTime.now())}',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.green.shade300 : Colors.green.shade800),
                                    ),
                                ],
                              ),
                            ),
                            if (_task.isCompleted)
                              IconButton(
                                icon: const Icon(Icons.send_rounded, size: 20, color: Colors.green),
                                tooltip: 'Erledigt-Meldung an Absender senden',
                                onPressed: () {
                                  TaskService.instance.shareCompletedNoticeViaWhatsApp(_task);
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Comments Section
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 18, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                          const SizedBox(width: 8),
                          Text(
                            'Kommentare & Verlauf (${_task.comments.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_task.comments.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF182647) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF283B63) : Colors.grey.shade200),
                          ),
                          child: Text(
                            'Noch keine Kommentare vorhanden. Schreibe unten eine Rückmeldung für den Absender.',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _task.comments.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final c = _task.comments[i];
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2A4C) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF283B63) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        c.author,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
                                        ),
                                      ),
                                      Text(
                                        timeFormat.format(c.createdAt),
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      color: isDark ? const Color(0xFFE2EDF8) : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),

                      // Add Comment Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF182647) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF283B63) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Neuen Kommentar hinzufügen:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 130,
                                  child: TextField(
                                    controller: _authorCtrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: 'Dein Name',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _commentCtrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Rückmeldung schreiben...',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onSubmitted: (_) => _addComment(),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: _isAddingComment
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.send_rounded, size: 16),
                                  onPressed: _isAddingComment ? null : _addComment,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              // Footer Actions: Responsive and adapting to full device / screen width
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 440;
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('Rückmeldung an Absender'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => TaskShareDialog(task: _task),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Schließen', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.reply_rounded, size: 18),
                            label: const Text('Rückmeldung an Absender', maxLines: 1, overflow: TextOverflow.ellipsis),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => TaskShareDialog(task: _task),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Schließen', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
