import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    String dateStr;
    try {
      final dateFormat = DateFormat('dd. MMM, HH:mm', 'de_DE');
      dateStr = dateFormat.format(note.updatedAt);
    } catch (_) {
      dateStr =
          '${note.updatedAt.day}.${note.updatedAt.month}. ${note.updatedAt.hour}:${note.updatedAt.minute.toString().padLeft(2, '0')}';
    }

    final cardColor = Color(note.colorValue);
    final isDarkBackground = ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark;
    final textColor = isDarkBackground ? Colors.white : Colors.black87;
    final subtextColor = isDarkBackground ? Colors.white70 : Colors.black54;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned
              ? Theme.of(context).colorScheme.primary.withAlpha(120)
              : Colors.black.withAlpha(15),
          width: note.isPinned ? 2 : 1,
        ),
      ),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title and Pin/Share/Stylus icons
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : 'Unbenannte Notiz',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.drawingImageBase64 != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Tooltip(
                        message: 'Enthält Stift-Zeichnung / Handschrift',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.draw_rounded, size: 15, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ),
                  if (note.isShared)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Tooltip(
                        message: 'Geteilte Notiz (${note.collaborators.length} Teilnehmer)',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.people_alt_rounded, size: 15, color: Colors.blue),
                        ),
                      ),
                    ),
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: note.isPinned ? Theme.of(context).colorScheme.primary : subtextColor,
                    ),
                    onPressed: onTogglePin,
                    tooltip: note.isPinned ? 'Lösen' : 'Anheften',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Content snippet
              if (note.content.isNotEmpty)
                Text(
                  note.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: subtextColor,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),

              // Drawing thumbnail if present
              if (note.drawingImageBase64 != null) ...[
                const SizedBox(height: 8),
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withAlpha(20)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    base64Decode(note.drawingImageBase64!),
                    fit: BoxFit.contain,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Tags
              if (note.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 8),

              // Footer: Date and Delete button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.red.shade400,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Löschen',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
