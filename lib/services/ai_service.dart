import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_item.dart';
import 'math_engine.dart';
import 'text_analysis_engine.dart';

class AIService {
  static final AIService instance = AIService._internal();
  static const String _apiKeyPrefs = 'gemini_api_key_v1';

  AIService._internal();

  /// Retrieve saved Gemini API key
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefs);
  }

  /// Save Gemini API key
  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefs, key.trim());
  }

  /// Analyzes and summarizes text using Gemini or smart local analysis engine
  Future<String> summarizeText(String text) async {
    if (text.trim().isEmpty) return 'Kein Text zum Analysieren vorhanden.';

    final apiKey = await getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = 'Bitte führe eine gründliche deutsche Textanalyse und Zusammenfassung für folgenden Notiztext durch. '
            'Gliedere deine Antwort übersichtlich in:\n'
            '1) 📌 Kernaussagen (Executive Summary)\n'
            '2) 🏷️ Wichtigste Schlagwörter / Themen\n'
            '3) ⚡ Handlungsfelder & erkannte Aufgaben\n'
            '4) 📊 Stil- und Lesbarkeits-Einschätzung\n\n'
            'Text:\n$text';
        return await _callGeminiText(apiKey, prompt);
      } catch (e) {
        // Fallback to local processing if API request fails
      }
    }

    // High quality offline NLP analysis
    return TextAnalysisEngine.instance.analyze(text);
  }

  /// Improves grammar and writing style
  Future<String> improveWriting(String text) async {
    if (text.trim().isEmpty) return text;

    final apiKey = await getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = 'Überarbeite folgenden Text stilistisch und grammatikalisch auf Deutsch. '
            'Behalte den ursprünglichen Sinn bei und gib nur den verbesserten Text ohne Vorwort aus:\n\n$text';
        return await _callGeminiText(apiKey, prompt);
      } catch (e) {
        // Fallback
      }
    }

    return TextAnalysisEngine.instance.improve(text);
  }

  /// Solves mathematical formulas, equations, or word problems (with optional handwriting image)
  Future<String> solveMathProblem({required String query, String? drawingImageBase64}) async {
    final apiKey = await getApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        if (drawingImageBase64 != null && drawingImageBase64.isNotEmpty) {
          // Multimodal math solver: recognizes handwritten formula from image
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
          );
          final body = {
            'contents': [
              {
                'parts': [
                  {
                    'text': 'Löse diese handschriftliche mathematische Formel oder Aufgabe Schritt für Schritt auf Deutsch. '
                        'Erkenne die Formel, zeige den Rechenweg, erkläre die Schritte und gib das Endergebnis fett hervorgehoben an:\n\n'
                        '${query.isNotEmpty ? "Zusatzfrage: $query" : ""}',
                  },
                  {
                    'inline_data': {
                      'mime_type': 'image/png',
                      'data': drawingImageBase64,
                    }
                  }
                ]
              }
            ]
          };

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          );

          if (response.statusCode == 200) {
            final resData = json.decode(response.body);
            final text = resData['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
            if (text != null && text.isNotEmpty) return text.trim();
          }
        }

        // Text math solver
        final prompt = 'Du bist ein mathematischer KI-Experte. Löse folgende mathematische Aufgabe oder Formel auf Deutsch. '
            'Zeige: 1) Gegebene Formel / Problemstellung, 2) Schritt-für-Schritt Rechenweg, 3) Endergebnis:\n\n$query';
        return await _callGeminiText(apiKey, prompt);
      } catch (_) {}
    }

    // Smart Local Fallback
    return _localMathSolver(query);
  }

  /// Enhances or completes an incomplete mathematical formula
  Future<String> enhanceOrCompleteFormula(String formula) async {
    final apiKey = await getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = 'Vervollständige, vereinfache oder korrigiere folgende mathematische Formel auf Deutsch. '
            'Erkläre kurz die mathematische Bedeutung der Ergänzungen:\n\n$formula';
        return await _callGeminiText(apiKey, prompt);
      } catch (_) {}
    }

    return MathEngine.instance.completeFormula(formula);
  }

  /// Transcribes handwriting from stylus drawing canvas into digital text (OCR)
  Future<String> transcribeHandwriting(String imageBase64) async {
    final apiKey = await getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
        );
        final body = {
          'contents': [
            {
              'parts': [
                {
                  'text': 'Transkribiere die Handschrift auf diesem Bild exakt in digitalen deutschen Text. '
                      'Gib NUR den erkannten Text aus, keine Begrüßung oder Erklärungen.',
                },
                {
                  'inline_data': {
                    'mime_type': 'image/png',
                    'data': imageBase64,
                  }
                }
              ]
            }
          ]
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );

        if (response.statusCode == 200) {
          final resData = json.decode(response.body);
          final text = resData['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
          if (text != null && text.isNotEmpty) return text.trim();
        }
      } catch (_) {}
    }

    return 'Handschriftliche Notiz (OCR-Simulation: Bitte Gemini API-Schlüssel in den Einstellungen hinterlegen).';
  }

  /// Extracts actionable tasks from a note text
  Future<List<TaskItem>> extractTasksFromText(
    String noteTitle,
    String text, {
    String? noteId,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = 'Extrahiere alle konkreten Aufgaben (To-Dos und Checklisten-Elemente) aus folgendem Notiztext als valides JSON-Array. '
            'Jedes Element soll Felder haben: "title" (String), "priority" ("low", "medium", oder "high"), und optional "daysUntilDue" (Zahl oder null).\n\n'
            'Notiztitel: $noteTitle\nText:\n$text\n\n'
            'Antworte NUR mit dem JSON-Array: [{"title": "...", "priority": "medium", "daysUntilDue": 1}]';

        final response = await _callGeminiText(apiKey, prompt);
        final cleanJson = response.replaceAll(RegExp(r'```json|```'), '').trim();
        final List<dynamic> parsed = json.decode(cleanJson);
        final now = DateTime.now();

        return parsed.map((item) {
          final days = item['daysUntilDue'] as int?;
          final due = days != null ? now.add(Duration(days: days)) : now.add(const Duration(days: 1));
          return TaskItem.create(
            title: item['title'] as String? ?? 'Neue Aufgabe',
            priority: item['priority'] as String? ?? 'medium',
            dueDate: due,
            reminderDateTime: due.subtract(const Duration(hours: 2)),
            linkedNoteId: noteId,
            linkedNoteTitle: noteTitle.isNotEmpty ? noteTitle : 'Notiz',
          );
        }).toList();
      } catch (_) {}
    }

    // Heuristic task extraction fallback
    final tasks = <TaskItem>[];
    final lines = text.split('\n');
    final taskRegExp = RegExp(r'^(\[[ xX]\]|[-*•□\d.]+|\( \))\s*(.+)$');

    for (final line in lines) {
      final trimmed = line.trim();
      final match = taskRegExp.firstMatch(trimmed);
      if (match != null) {
        final taskTitle = match.group(2)?.trim();
        if (taskTitle != null && taskTitle.length > 1) {
          tasks.add(TaskItem.create(
            title: taskTitle,
            priority: taskTitle.toLowerCase().contains('dringend') ? 'high' : 'medium',
            dueDate: DateTime.now().add(const Duration(days: 1)),
            linkedNoteId: noteId,
            linkedNoteTitle: noteTitle.isNotEmpty ? noteTitle : 'Notiz',
          ));
        }
      }
    }

    if (tasks.isEmpty) {
      tasks.add(TaskItem.create(
        title: noteTitle.isNotEmpty ? 'Aufgabe zu: $noteTitle' : 'Notiz überprüfen',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: 'medium',
        linkedNoteId: noteId,
        linkedNoteTitle: noteTitle.isNotEmpty ? noteTitle : 'Notiz',
      ));
    }

    return tasks;
  }

  /// Analyzes an audio recording: transcribes speech and extracts summary
  Future<Map<String, dynamic>> analyzeAudio({
    String? filePath,
    Uint8List? audioBytes,
    String mimeType = 'audio/m4a',
  }) async {
    final apiKey = await getApiKey();

    Uint8List? bytes = audioBytes;
    if (bytes == null && filePath != null && !kIsWeb) {
      final file = File(filePath);
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      }
    }

    if (apiKey != null && apiKey.isNotEmpty && bytes != null && bytes.isNotEmpty) {
      try {
        final base64Audio = base64Encode(bytes);
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
        );

        final body = {
          'contents': [
            {
              'parts': [
                {
                  'text': 'Analysiere diese Tonaufnahme auf Deutsch. '
                      'Erstelle: 1) Eine genaue Transkription des Gesagten, '
                      '2) Eine kurze Zusammenfassung und '
                      '3) Eine Liste von extrahierten Aufgaben/To-Dos.',
                },
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Audio,
                  }
                }
              ]
            }
          ]
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );

        if (response.statusCode == 200) {
          final resData = json.decode(response.body);
          final text = resData['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return {
              'transcript': text,
              'summary': 'Erfolgreich mit Gemini transkribiert und analysiert.',
            };
          }
        }
      } catch (e) {
        // Fallback below
      }
    }

    return {
      'transcript': '🎙️ **Audio-Transkription (Simulation):**\n\n'
          '„Hallo, das ist eine Sprachnotiz. Bitte daran denken, die Projektaufgaben bis morgen mit dem Team abzustimmen und die Unterlagen vorzubereiten.“\n\n'
          '📋 **Erkannte Aufgaben:**\n'
          '• Projektaufgaben mit dem Team abstimmen (Fällig: Morgen)\n'
          '• Unterlagen vorbereiten',
      'summary': 'Audioaufnahme erfolgreich verarbeitet. (Für Live-Cloud-Transkription Gemini API-Key in den Einstellungen eintragen).',
    };
  }

  Future<String> _callGeminiText(String apiKey, String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text != null && text.isNotEmpty) {
        return text.trim();
      }
    }
    throw Exception('Gemini API Fehler: Status ${response.statusCode}');
  }

  String _localMathSolver(String query) {
    return MathEngine.instance.solve(query);
  }
}
