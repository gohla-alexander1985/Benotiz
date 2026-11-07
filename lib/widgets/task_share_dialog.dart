import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';

class TaskShareDialog extends StatelessWidget {
  final TaskItem task;

  const TaskShareDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueStr = task.dueDate != null
        ? '${task.dueDate!.day}.${task.dueDate!.month}.${task.dueDate!.year}'
        : 'Kein Fälligkeitsdatum';

    final taskUrl = '${TaskService.appBaseUrl}/?task=${task.id}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share_rounded, color: Color(0xFF1565C0), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aufgabe teilen',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Wähle, wie du die Aufgabe weiterleiten möchtest',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Task Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: task.priority == 'high'
                                ? Colors.red.shade50
                                : task.priority == 'medium'
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.priority.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: task.priority == 'high'
                                  ? Colors.red.shade700
                                  : task.priority == 'medium'
                                      ? Colors.orange.shade800
                                      : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fällig: $dueStr ${task.assignedGroup != null ? "• Gruppe: ${task.assignedGroup}" : ""}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (task.linkedNoteTitle != null && task.linkedNoteTitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Notiz: ${task.linkedNoteTitle}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sharing Options List
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE3F2FD),
                  child: const Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
                ),
                title: const Text('Per E-Mail versenden', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Öffnet Ihr Mailprogramm (Outlook, Mail, Gmail)', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  Navigator.pop(context);
                  await TaskService.instance.shareTaskViaEmail(task);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2E7D32)),
                ),
                title: const Text('Per WhatsApp teilen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Direkt an Kontakt oder Gruppe senden', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  Navigator.pop(context);
                  await TaskService.instance.shareTaskViaWhatsApp(task);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFF3E0),
                  child: const Icon(Icons.copy_rounded, color: Color(0xFFE65100)),
                ),
                title: const Text('Text & Link kopieren', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('In die Zwischenablage für Teams, SMS etc.', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  await TaskService.instance.copyTaskToClipboard(task);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('📋 Aufgabe und Link wurden in die Zwischenablage kopiert!'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF3E5F5),
                  child: const Icon(Icons.share_outlined, color: Color(0xFF7B1FA2)),
                ),
                title: const Text('System-Dialog (Weitere Apps)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Über allgemeines Betriebssystem-Menü teilen', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  Navigator.pop(context);
                  await TaskService.instance.shareTask(task);
                },
              ),

              const SizedBox(height: 14),
              // App Link indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        taskUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
