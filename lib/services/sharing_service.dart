import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import 'storage_service.dart';

class SharingService {
  static const String appBaseUrl = 'https://gohla-alexander1985.github.io/Benotiz';
  static final SharingService instance = SharingService._internal();

  SharingService._internal();

  /// Generates or returns an existing share link for a note
  String generateShareLink(Note note) {
    final token = note.shareToken ?? const Uuid().v4().substring(0, 8);
    return '$appBaseUrl/?note=${note.id}&token=$token&perm=${note.permission}';
  }

  /// Copies the invitation link to the system clipboard
  Future<void> copyLinkToClipboard(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Shares a note directly via Email
  Future<bool> shareViaEmail(Note note) async {
    final link = generateShareLink(note);
    final subject = 'Einladung zur Notiz: ${note.title.isNotEmpty ? note.title : "Notiz"}';
    final body = 'Hallo,\n\nich habe eine Notiz in BEnotiz mit dir geteilt:\n\n'
        'Titel: "${note.title.isNotEmpty ? note.title : "Unbenannte Notiz"}"\n\n'
        'Hier kannst du die Notiz direkt in BEnotiz öffnen und ansehen:\n$link\n';

    final mailtoUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    try {
      return await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Shares a note directly via WhatsApp
  Future<bool> shareViaWhatsApp(Note note) async {
    final link = generateShareLink(note);
    final text = 'Hallo, ich habe eine Notiz in BEnotiz mit dir geteilt:\n"${note.title.isNotEmpty ? note.title : "Notiz"}"\n\n$link';
    final waUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');
    try {
      return await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
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
      String? noteId;

      if (uri.queryParameters.containsKey('note')) {
        noteId = uri.queryParameters['note'];
      } else if (uri.pathSegments.contains('n')) {
        final noteIndex = uri.pathSegments.indexOf('n');
        if (noteIndex + 1 < uri.pathSegments.length) {
          noteId = uri.pathSegments[noteIndex + 1];
        }
      }

      if (noteId == null || noteId.isEmpty) {
        return null;
      }
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
