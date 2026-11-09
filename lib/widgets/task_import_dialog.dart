import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import 'task_detail_dialog.dart';

class TaskImportDialog extends StatelessWidget {
  final TaskItem importedTask;
  final VoidCallback onImported;

  const TaskImportDialog({
    super.key,
    required this.importedTask,
    required this.onImported,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');
    final dueStr = importedTask.dueDate != null
        ? dateFormat.format(importedTask.dueDate!)
        : 'Kein Fälligkeitsdatum';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF143020) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment_returned_rounded, color: isDark ? Colors.green.shade300 : const Color(0xFF2E7D32), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Neue Aufgabe empfangen!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Möchtest du diese Aufgabe in deine Aufgabenliste übernehmen?',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Task Preview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF182647) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF283B63) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            importedTask.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: importedTask.priority == 'high'
                                ? (isDark ? Colors.red.withAlpha(40) : Colors.red.shade50)
                                : (isDark ? Colors.orange.withAlpha(40) : Colors.orange.shade50),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            importedTask.priority.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: importedTask.priority == 'high'
                                  ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                                  : (isDark ? Colors.orange.shade300 : Colors.orange.shade800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (importedTask.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        importedTask.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: isDark ? const Color(0xFFE2EDF8) : Colors.black87,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Divider(height: 1, color: isDark ? const Color(0xFF283B63) : Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Fällig: $dueStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const Spacer(),
                        if (importedTask.creatorName != null && importedTask.creatorName!.isNotEmpty) ...[
                          Icon(Icons.person_outline_rounded, size: 13, color: isDark ? const Color(0xFF90CAF9) : Colors.indigo),
                          const SizedBox(width: 4),
                          Text(
                            'Von: ${importedTask.creatorName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF90CAF9) : Colors.indigo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (importedTask.comments.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '💬 ${importedTask.comments.length} Kommentar(e) bereits vorhanden',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Responsive Action Buttons
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 380;
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_task_rounded),
                          label: const Text('In Aufgaben übernehmen', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await TaskService.instance.saveOrUpdateTask(importedTask);
                            onImported();
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Aufgabe "${importedTask.title}" wurde in deine Aufgabenliste übernommen!'),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              showDialog(
                                context: context,
                                builder: (_) => TaskDetailDialog(
                                  task: importedTask,
                                  onUpdated: onImported,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Später'),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Später'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('In Aufgaben übernehmen', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              await TaskService.instance.saveOrUpdateTask(importedTask);
                              onImported();
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Aufgabe "${importedTask.title}" wurde in deine Aufgabenliste übernommen!'),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                showDialog(
                                  context: context,
                                  builder: (_) => TaskDetailDialog(
                                    task: importedTask,
                                    onUpdated: onImported,
                                  ),
                                );
                              }
                            },
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
}
