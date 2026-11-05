import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

class StorageService {
  static const String _storageKey = 'antigravity_notes_v1';
  static final StorageService instance = StorageService._internal();

  StorageService._internal();

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString(_storageKey);

    if (notesJson == null || notesJson.isEmpty) {
      // Create welcoming sample notes
      final sampleNotes = _createSampleNotes();
      await saveNotes(sampleNotes);
      return sampleNotes;
    }

    try {
      final List<dynamic> decoded = json.decode(notesJson);
      return decoded.map((item) => Note.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      // Fallback if data corrupted
      return [];
    }
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(notes.map((n) => n.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> saveOrUpdateNote(Note note) async {
    final notes = await loadNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.insert(0, note);
    }
    await saveNotes(notes);
  }

  Future<void> deleteNote(String noteId) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == noteId);
    await saveNotes(notes);
  }

  List<Note> _createSampleNotes() {
    final now = DateTime.now();
    const uuid = Uuid();
    return [
      Note(
        id: uuid.v4(),
        title: 'Willkommen bei BEnotiz! 🚀',
        content: 'BEnotiz speichert deine Notizen und Aufgaben primär lokal und blitzschnell auf deinem Gerät.\n\n'
            '✨ Funktionen:\n'
            '• 100% Offline-fähig auf Android, iOS und Windows\n'
            '• Integrierter KI-Agent für Text- & Audio-Analysen\n'
            '• Aufgabenverwaltung mit Fälligkeit & Erinnerungen\n'
            '• Notizen & Aufgaben per Link teilen und versenden',
        createdAt: now,
        updatedAt: now,
        isPinned: true,
        colorValue: 0xFFE3F2FD, // Eisblau
        tags: ['Willkommen', 'BEnotiz'],
        isShared: false,
      ),
      Note(
        id: uuid.v4(),
        title: 'Geteilte Notiz: Projektbesprechung 📊',
        content: 'Agenda:\n- Meilensteine durchgehen\n- Neue Aufgaben zuteilen\n- Feedback besprechen\n\nTippe oben auf das Teilen-Symbol, um den Einladungslink anzusehen!',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        isPinned: false,
        colorValue: 0xFFBBDEFB, // Soft Sky Blue
        tags: ['Projekt', 'Team'],
        isShared: true,
        shareToken: 'project-benotiz-share',
        collaborators: ['anna@example.com', 'max@example.com'],
        permission: 'edit',
      ),
    ];
  }
}
