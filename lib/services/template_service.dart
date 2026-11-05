import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_template.dart';

class TemplateService {
  static const String _customTemplatesKey = 'benotiz_custom_templates_v1';
  static final TemplateService instance = TemplateService._internal();

  TemplateService._internal();

  List<NoteTemplate> getBuiltInTemplates() {
    return [
      NoteTemplate(
        id: 'builtin_blank',
        name: 'A4 Blanko',
        description: 'Klassisches weißes DIN A4 Papier ohne Hilfslinien.',
        paperType: 'blank',
      ),
      NoteTemplate(
        id: 'builtin_grid',
        name: 'A4 Kariert (5 mm)',
        description: 'Exaktes 5mm Rechenkästchen-Raster – ideal für Mathematik, Formeln und technische Skizzen.',
        paperType: 'grid',
      ),
      NoteTemplate(
        id: 'builtin_lined',
        name: 'A4 Liniert (mit Korrekturrand)',
        description: 'Klassische Schreiblinien mit rotem Rand für handschriftliche Mitschriften und Aufsätze.',
        paperType: 'lined',
      ),
      NoteTemplate(
        id: 'builtin_dots',
        name: 'A4 Punktraster (Dot Grid)',
        description: 'Dezentes Punktraster für Bullet Journaling, Sketchnotes und freie Struktur.',
        paperType: 'dots',
      ),
      NoteTemplate(
        id: 'builtin_cornell',
        name: 'A4 Cornell-Lernmethode',
        description: 'Stichwort-Spalte links, Mitschrift rechts und Zusammenfassungs-Bereich unten.',
        paperType: 'cornell',
        defaultTitle: 'Vorlesung / Thema: ',
        defaultContent: 'STICHWORTE & FRAGEN (Links):\n- Kernbegriff 1\n- Kernbegriff 2\n\n'
            'NOTIZEN & DETAILS (Rechts):\n• Ausführliche Erklärungen...\n\n'
            'ZUSAMMENFASSUNG (Unten):\n',
      ),
      NoteTemplate(
        id: 'builtin_meeting',
        name: 'A4 Meeting-Protokoll',
        description: 'Strukturierte Vorlage mit Agenda, Teilnehmern, Beschlüssen und Aufgaben.',
        paperType: 'meeting',
        defaultTitle: 'Meeting: ',
        defaultContent: '📋 AGENDA:\n1. Stand der Dinge\n2. Herausforderungen\n3. Nächste Schritte\n\n'
            '👥 TEILNEHMER:\n- \n\n'
            '📝 BESCHLÜSSE:\n• \n\n'
            '☑️ AUFGABEN:\n[ ] Aufgabe 1 (Fällig: )\n[ ] Aufgabe 2 (Fällig: )\n',
      ),
      NoteTemplate(
        id: 'builtin_planner',
        name: 'A4 Tages- & Wochenplaner',
        description: 'Fokus des Tages, Zeitplan und Checkliste für hohe Produktivität.',
        paperType: 'planner',
        defaultTitle: 'Tagesplan: ',
        defaultContent: '🎯 TOP 3 PRIORITÄTEN:\n1. \n2. \n3. \n\n'
            '⏰ ZEITPLAN:\n• 09:00 -\n• 11:00 -\n• 14:00 -\n• 16:00 -\n\n'
            '☑️ TO-DO LISTE:\n[ ] \n[ ] \n[ ] \n',
      ),
    ];
  }

  Future<List<NoteTemplate>> loadAllTemplates() async {
    final builtIn = getBuiltInTemplates();
    final custom = await loadCustomTemplates();
    return [...builtIn, ...custom];
  }

  Future<List<NoteTemplate>> loadCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_customTemplatesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((item) => NoteTemplate.fromMap(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomTemplate(NoteTemplate template) async {
    final custom = await loadCustomTemplates();
    final index = custom.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      custom[index] = template;
    } else {
      custom.insert(0, template);
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(custom.map((t) => t.toMap()).toList());
    await prefs.setString(_customTemplatesKey, encoded);
  }

  Future<void> deleteCustomTemplate(String templateId) async {
    final custom = await loadCustomTemplates();
    custom.removeWhere((t) => t.id == templateId);

    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(custom.map((t) => t.toMap()).toList());
    await prefs.setString(_customTemplatesKey, encoded);
  }
}
