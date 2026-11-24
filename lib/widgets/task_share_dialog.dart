import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';

class TaskShareDialog extends StatefulWidget {
  final TaskItem task;

  const TaskShareDialog({super.key, required this.task});

  @override
  State<TaskShareDialog> createState() => _TaskShareDialogState();
}

class _TaskShareDialogState extends State<TaskShareDialog> {
  List<AppUser> _users = [];
  List<String> _groups = [];
  bool _isLoadingTeam = true;
  AppUser? _selectedRecipientUser;
  String? _selectedRecipientGroup;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final users = await UserService.instance.getUsers();
    final groups = await UserService.instance.getAllGroups();
    setState(() {
      _users = users;
      _groups = groups;
      _isLoadingTeam = false;

      // Auto-select if task.assignedTo matches a user
      if (widget.task.assignedTo != null && widget.task.assignedTo!.isNotEmpty) {
        final match = users.where((u) =>
            u.fullName.toLowerCase() == widget.task.assignedTo!.toLowerCase() ||
            u.email.toLowerCase() == widget.task.assignedTo!.toLowerCase());
        if (match.isNotEmpty) {
          _selectedRecipientUser = match.first;
        }
      }
      if (widget.task.assignedGroup != null && widget.task.assignedGroup!.isNotEmpty) {
        _selectedRecipientGroup = widget.task.assignedGroup;
      }
    });
  }

  void _shareWithUser(AppUser user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(user.colorValue),
                      foregroundColor: Colors.white,
                      child: Text(user.initials),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Senden an: ${user.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${user.position.isNotEmpty ? "${user.position} • " : ""}${user.email}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
                ),
                title: Text('Per E-Mail an ${user.email} senden', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Öffnet E-Mail-Programm mit vorausgefüllter Adresse & Aufgabe'),
                onTap: () async {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  await TaskService.instance.shareTaskViaEmail(widget.task, recipientEmail: user.email);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2E7D32)),
                ),
                title: const Text('Per WhatsApp teilen', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Sendet Aufgabendetails & Direkt-Link'),
                onTap: () async {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  await TaskService.instance.shareTaskViaWhatsApp(widget.task);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.copy_rounded, color: Color(0xFFE65100)),
                ),
                title: const Text('Link & Text kopieren', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  await TaskService.instance.copyTaskToClipboard(widget.task);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📋 Link für ${user.fullName} kopiert!')),
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

  void _shareWithGroup(String groupName) {
    final groupMembers = _users.where((u) => u.groups.contains(groupName)).toList();
    final emails = groupMembers.map((u) => u.email).where((e) => e.isNotEmpty).join(',');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1565C0),
                      child: Icon(Icons.group_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gruppe: $groupName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${groupMembers.length} Mitglied(er) in dieser Gruppe', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
                ),
                title: Text('Per E-Mail an Gruppe "$groupName" senden', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(emails.isNotEmpty ? 'Empfänger: $emails' : 'Keine E-Mail-Adressen hinterlegt'),
                onTap: () async {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  await TaskService.instance.shareTaskViaEmail(widget.task, recipientEmail: emails);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2E7D32)),
                ),
                title: const Text('Per WhatsApp an Gruppe teilen', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  await TaskService.instance.shareTaskViaWhatsApp(widget.task);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dueStr = task.dueDate != null
        ? '${task.dueDate!.day}.${task.dueDate!.month}.${task.dueDate!.year}'
        : 'Kein Fälligkeitsdatum';

    final taskUrl = TaskService.instance.generateTaskShareLink(task);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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
                            'Aufgabe verteilen & senden',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Wähle Benutzer oder Gruppe zum direkten Versenden',
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
                const SizedBox(height: 16),

                // USER & GROUP SELECTION SECTION
                Text(
                  'TEAM-MITGLIED ODER GRUPPE AUSWÄHLEN:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),

                if (_isLoadingTeam)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else ...[
                  // Groups quick chips
                  if (_groups.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _groups.map((group) {
                          final isGroupSelected = _selectedRecipientGroup == group;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.group_rounded, size: 14),
                              label: Text(group, style: const TextStyle(fontSize: 12)),
                              backgroundColor: isGroupSelected ? theme.colorScheme.primary.withAlpha(40) : null,
                              onPressed: () => _shareWithGroup(group),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // User selection horizontal list
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _users.map((user) {
                        final isSelected = _selectedRecipientUser?.id == user.id;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _shareWithUser(user),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withAlpha(25)
                                    : (isDark ? const Color(0xFF182647) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(user.colorValue),
                                    foregroundColor: Colors.white,
                                    child: Text(user.initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      if (user.position.isNotEmpty)
                                        Text(user.position, style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 10),

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
                  title: const Text('Allgemein per E-Mail versenden', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Öffnet Mailprogramm (Outlook, Mail, Gmail)', style: TextStyle(fontSize: 12)),
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
                  title: const Text('Allgemein per WhatsApp teilen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Direkt an Kontakt oder Chat senden', style: TextStyle(fontSize: 12)),
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
