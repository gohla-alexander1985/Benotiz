import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/sharing_service.dart';

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

  void _addCollaborator() {
    final text = _inviteEmailController.text.trim();
    if (text.isNotEmpty && !_collaborators.contains(text)) {
      setState(() {
        _collaborators.add(text);
        _inviteEmailController.clear();
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

  @override
  Widget build(BuildContext context) {
    final shareLink = SharingService.instance.generateShareLink(widget.note);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                      child: Icon(Icons.share_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notiz teilen & einladen',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Andere können über den Link mitarbeiten',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Link Sharing Box
                Text(
                  'Einladungs-Link',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
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
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
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

                // Quick Action Share
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Link über Messenger / E-Mail teilen'),
                    onPressed: () => SharingService.instance.shareViaSystemDialog(widget.note),
                  ),
                ),

                const SizedBox(height: 20),
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

                const SizedBox(height: 20),
                Text(
                  'Eingeladene Personen',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteEmailController,
                        decoration: InputDecoration(
                          hintText: 'E-Mail oder Name eingeben',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _addCollaborator,
                      child: const Text('Hinzufügen'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
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
