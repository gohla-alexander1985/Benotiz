import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';

class TaskShareDialog extends StatelessWidget {
  final TaskItem task;

  const TaskShareDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dueStr = task.dueDate != null
        ? '${task.dueDate!.day}.${task.dueDate!.month}.${task.dueDate!.year}'
        : 'Kein Fälligkeitsdatum';

    final taskUrl = TaskService.instance.generateTaskShareLink(task);

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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF162A48) : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.share_rounded, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aufgabe teilen & senden',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Der Empfänger kann die Aufgabe öffnen, kommentieren & erledigen',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
                const SizedBox(height: 16),

                // Overdue Alert Banner if applicable
                if (task.isOverdue) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.withAlpha(40) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Achtung: Frist abgelaufen ($dueStr)! Du kannst eine Mahnung/Erinnerung senden.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Task Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
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
                          Icon(
                            task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 18,
                            color: task.isCompleted ? Colors.green : (isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: task.priority == 'high'
                                  ? (isDark ? Colors.red.withAlpha(40) : Colors.red.shade50)
                                  : task.priority == 'medium'
                                      ? (isDark ? Colors.orange.withAlpha(40) : Colors.orange.shade50)
                                      : (isDark ? Colors.green.withAlpha(40) : Colors.green.shade50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: task.priority == 'high'
                                    ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                                    : task.priority == 'medium'
                                        ? (isDark ? Colors.orange.shade300 : Colors.orange.shade800)
                                        : (isDark ? Colors.green.shade300 : Colors.green.shade800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fällig: $dueStr ${task.assignedGroup != null ? "• Gruppe: ${task.assignedGroup}" : ""}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      if (task.creatorName != null && task.creatorName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Erstellt von: ${task.creatorName}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                      ],
                      if (task.comments.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '💬 ${task.comments.length} Kommentar(e) vorhanden',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Special Overdue Reminder Options
                if (task.isOverdue) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: const Icon(Icons.alarm_on_rounded, color: Colors.red),
                    ),
                    title: const Text('⚠️ Dringende Frist-Mahnung versenden',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                    subtitle: const Text('Erinnert Empfänger per Mail oder WhatsApp an die Frist',
                        style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () async {
                      Navigator.pop(context);
                      await TaskService.instance.shareOverdueReminderViaEmail(task);
                    },
                  ),
                  const Divider(height: 1),
                ],

                // Special Completed Notice Option
                if (task.isCompleted) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.done_all_rounded, color: Colors.green),
                    ),
                    title: const Text('✅ Erledigt-Mitteilung an Absender senden',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                    subtitle: const Text('Informiert Absender, dass die Aufgabe erledigt wurde',
                        style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () async {
                      Navigator.pop(context);
                      await TaskService.instance.shareCompletedNoticeViaEmail(task);
                    },
                  ),
                  const Divider(height: 1),
                ],

                // Standard Sharing Options
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
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
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2E7D32)),
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
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.copy_rounded, color: Color(0xFFE65100)),
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
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E5F5),
                    child: Icon(Icons.share_outlined, color: Color(0xFF7B1FA2)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162340) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF283B63) : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 16, color: isDark ? const Color(0xFF90CAF9) : Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          taskUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Responsive Full-width close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Schließen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
