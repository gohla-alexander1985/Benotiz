import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import 'storage_service.dart';

class SharingService {
  static final SharingService instance = SharingService._internal();

  SharingService._internal();

  /// Generates or returns an existing share link for a note
  String generateShareLink(Note note) {
    final token = note.shareToken ?? const Uuid().v4().substring(0, 8);
    return 'https://benotiz.app/n/${note.id}?token=$token&perm=${note.permission}';
  }

  /// Copies the invitation link to the system clipboard
  Future<void> copyLinkToClipboard(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Opens the native OS share dialog (WhatsApp, Mail, etc.)
  Future<void> shareViaSystemDialog(Note note) async {
    final link = generateShareLink(note);
    final text = 'Ich habe eine Notiz mit dir geteilt: "${note.title.isNotEmpty ? note.title : 'Unbenannte Notiz'}"\n\n'
        'Öffne den Link in der Notiz-App:\n$link';
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Einladung zur Notiz: ${note.title}',
      ),
    );
  }

  /// Simulates importing/joining a note when opening an invitation link
  Future<Note?> joinNoteFromLink(String urlString) async {
    try {
      final uri = Uri.parse(urlString.trim());
      if (!uri.pathSegments.contains('n') || uri.pathSegments.isEmpty) {
        return null;
      }
      
      final noteIndex = uri.pathSegments.indexOf('n');
      if (noteIndex + 1 >= uri.pathSegments.length) return null;
      final noteId = uri.pathSegments[noteIndex + 1];
      final token = uri.queryParameters['token'] ?? 'guest-token';
      final perm = uri.queryParameters['perm'] ?? 'edit';

      // Check if already in local storage
      final localNotes = await StorageService.instance.loadNotes();
      final existing = localNotes.where((n) => n.id == noteId);
      if (existing.isNotEmpty) {
        return existing.first;
      }

      // In a live Supabase environment, here we fetch the note row from the cloud.
      // For standalone/local-first, we create a synced placeholder note
      final now = DateTime.now();
      final newJoinedNote = Note(
        id: noteId,
        title: 'Gemeinsame Notiz (Importiert)',
        content: 'Dies ist eine importierte Notiz aus der Einladung.\nLink-Token: $token\n\n'
            'Änderungen werden synchronisiert, sobald das Cloud-Backend angebunden ist.',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        colorValue: 0xFFE0F7FA, // Cyan
        tags: ['Geteilt', 'Importiert'],
        isShared: true,
        shareToken: token,
        collaborators: ['Du (Eingeladen)'],
        permission: perm,
      );

      await StorageService.instance.saveOrUpdateNote(newJoinedNote);
      return newJoinedNote;
    } catch (e) {
      return null;
    }
  }
}
