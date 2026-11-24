import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/note.dart';
import '../services/sharing_service.dart';
import '../services/user_service.dart';
import 'user_picker_sheet.dart';

class ShareDialog extends StatefulWidget {
  final Note note;
  final ValueChanged<Note> onNoteUpdated;

  const ShareDialog({
    super.key,
    required this.note,
    required this.onNoteUpdated,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  late bool _isShared;
  late String _permission;
  late List<String> _collaborators;
  final TextEditingController _inviteEmailController = TextEditingController();
  List<AppUser> _teamUsers = [];
  List<String> _groups = [];
  bool _isLoadingTeam = true;

  @override
  void initState() {
    super.initState();
    _isShared = widget.note.isShared;
    _permission = widget.note.permission;
    _collaborators = List.from(widget.note.collaborators);

    // If enabling sharing for the first time, generate a token
    if (!_isShared) {
      _isShared = true;
      _updateNote();
    }

    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final users = await UserService.instance.getUsers();
    final groups = await UserService.instance.getAllGroups();
    setState(() {
      _teamUsers = users;
      _groups = groups;
      _isLoadingTeam = false;
    });
  }

  void _updateNote() {
    final updated = widget.note.copyWith(
      isShared: _isShared,
      permission: _permission,
      shareToken: widget.note.shareToken ?? const Uuid().v4().substring(0, 8),
      collaborators: _collaborators,
    );
    widget.onNoteUpdated(updated);
  }

  void _addCollaborator([String? custom]) {
    final text = custom ?? _inviteEmailController.text.trim();
    if (text.isNotEmpty && !_collaborators.contains(text)) {
      setState(() {
        _collaborators.add(text);
        if (custom == null) _inviteEmailController.clear();
      });
      _updateNote();
    }
  }

  void _removeCollaborator(String email) {
    setState(() {
      _collaborators.remove(email);
    });
    _updateNote();
  }

  void _openUserPicker() async {
    final selected = await UserPickerSheet.show(context);
    if (selected != null) {
      if (selected.isUser) {
        final user = selected.user!;
        final identifier = user.email.isNotEmpty ? user.email : user.fullName;
        _addCollaborator(identifier);
      } else if (selected.isGroup) {
        final group = selected.group!;
        final members = _teamUsers.where((u) => u.groups.contains(group)).toList();
        for (final m in members) {
          final id = m.email.isNotEmpty ? m.email : m.fullName;
          _addCollaborator(id);
        }
        _addCollaborator('#$group');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareLink = SharingService.instance.generateShareLink(widget.note);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      child: Icon(Icons.share_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notiz teilen & einladen',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'Wähle Benutzer & Gruppen zur gemeinsamen Bearbeitung',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // USER & GROUP SELECTION SECTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AUS TEAM & GRUPPEN HINZUFÜGEN:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.people_alt_outlined, size: 15),
                      label: const Text('Alle anzeigen...', style: TextStyle(fontSize: 11)),
                      onPressed: _openUserPicker,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_isLoadingTeam)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else ...[
                  // Group Chips
                  if (_groups.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _groups.map((group) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.group_rounded, size: 13),
                              label: Text(group, style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                final members = _teamUsers.where((u) => u.groups.contains(group)).toList();
                                for (final m in members) {
                                  _addCollaborator(m.email.isNotEmpty ? m.email : m.fullName);
                                }
                                _addCollaborator('#$group');
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // User Quick Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _teamUsers.map((user) {
                        final isAlreadyAdded = _collaborators.contains(user.email) || _collaborators.contains(user.fullName);

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            avatar: CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(user.colorValue),
                              foregroundColor: Colors.white,
                              child: Text(user.initials, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            label: Text(user.fullName, style: const TextStyle(fontSize: 11)),
                            selected: isAlreadyAdded,
                            onSelected: (_) {
                              if (isAlreadyAdded) {
                                _removeCollaborator(user.email);
                                _removeCollaborator(user.fullName);
                              } else {
                                _addCollaborator(user.email.isNotEmpty ? user.email : user.fullName);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Link Sharing Box
                Text(
                  'Einladungs-Link',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162340) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF283B63) : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shareLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Link kopieren',
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () async {
                          await SharingService.instance.copyLinkToClipboard(shareLink);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link in Zwischenablage kopiert!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Action Share Buttons (E-Mail, WhatsApp, System)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('Per E-Mail'),
                        onPressed: () => SharingService.instance.shareViaEmail(widget.note),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: const Text('Per WhatsApp'),
                        onPressed: () => SharingService.instance.shareViaWhatsApp(widget.note),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Über andere Apps teilen...'),
                    onPressed: () => SharingService.instance.shareViaSystemDialog(widget.note),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'Berechtigung für Link-Inhaber',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'edit',
                      label: Text('Darf bearbeiten'),
                      icon: Icon(Icons.edit_outlined),
                    ),
                    ButtonSegment(
                      value: 'read_only',
                      label: Text('Nur ansehen'),
                      icon: Icon(Icons.visibility_outlined),
                    ),
                  ],
                  selected: {_permission},
                  onSelectionChanged: (set) {
                    setState(() {
                      _permission = set.first;
                    });
                    _updateNote();
                  },
                ),

                const SizedBox(height: 16),
                Text(
                  'Teilnehmer & Kollaborateure (${_collaborators.length})',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteEmailController,
                        decoration: InputDecoration(
                          hintText: 'E-Mail oder Name manuell eingeben...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => _addCollaborator(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _addCollaborator(),
                      child: const Text('Hinzufügen'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_collaborators.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Noch keine direkten Teilnehmer hinzugefügt.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _collaborators.map((email) {
                      return Chip(
                        avatar: const CircleAvatar(
                          child: Icon(Icons.person, size: 14),
                        ),
                        label: Text(email),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeCollaborator(email),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fertig'),
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
