import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/note_template.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/task_service.dart';
import '../widgets/a4_paper_sheet.dart';
import '../widgets/audio_recorder_sheet.dart';
import '../widgets/be_notiz_logo.dart';
import '../widgets/checklist_to_tasks_dialog.dart';
import '../widgets/draggable_tool_dock.dart';
import '../widgets/math_ai_dialog.dart';
import '../widgets/share_dialog.dart';
import '../widgets/stylus_canvas_screen.dart';
import '../widgets/template_picker_dialog.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;

  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  late Note _currentNote;
  bool _hasChanges = false;
  bool _isAIBusy = false;
  bool _keyboardEnabled = false; // Primary input is Lenovo Pen / Stylus! Tastatur erst nach Button-Klick!

  // In-note search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Embedded images (base64)
  final List<String> _embeddedImages = [];

  final List<int> _colorPalette = const [
    0xFFFFFFFF, // Weiß / Standard
    0xFFE3F2FD, // Eisblau
    0xFFBBDEFB, // Himmelblau
    0xFF90CAF9, // Ozeanblau
    0xFFE1F5FE, // Gletscherblau
    0xFFE0F7FA, // Türkis / Aquablau
    0xFFC5CAE9, // Sanftes Indigoblau
    0xFFCFD8DC, // Schieferblau
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initialNote = widget.note;

    if (initialNote != null && initialNote.id.isNotEmpty) {
      _currentNote = initialNote;
    } else {
      _currentNote = Note(
        id: const Uuid().v4(),
        title: initialNote?.title ?? '',
        content: initialNote?.content ?? '',
        createdAt: now,
        updatedAt: now,
        colorValue: 0xFFFFFFFF,
        paperType: initialNote?.paperType ?? 'blank',
        templateImageBase64: initialNote?.templateImageBase64,
      );
    }

    _titleController = TextEditingController(text: _currentNote.title);
    _contentController = TextEditingController(text: _currentNote.content);

    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleKeyboard() {
    setState(() {
      _keyboardEnabled = !_keyboardEnabled;
    });

    if (!_keyboardEnabled) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✍️ Stift-Modus aktiv: Tastatur ausgeblendet (Lenovo Pen)'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⌨️ Tastatur aktiviert: Du kannst nun Text tippen'),
          duration: Duration(seconds: 2),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contentFocusNode.requestFocus();
      });
    }
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty &&
        content.isEmpty &&
        _currentNote.drawingData == null &&
        _embeddedImages.isEmpty &&
        widget.note == null) {
      return;
    }

    final updated = _currentNote.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
      paperType: _currentNote.paperType,
      templateImageBase64: _currentNote.templateImageBase64,
    );

    await StorageService.instance.saveOrUpdateNote(updated);
  }

  void _openStylusCanvas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => StylusCanvasScreen(
          title: _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : _currentNote.title,
          initialDrawingData: _currentNote.drawingData,
          paperType: _currentNote.paperType,
          onSave: (strokeJson, imageBase64) {
            setState(() {
              _currentNote = _currentNote.copyWith(
                drawingData: strokeJson,
                drawingImageBase64: imageBase64,
              );
              _hasChanges = true;
            });
            StorageService.instance.saveOrUpdateNote(_currentNote);
          },
        ),
      ),
    );
  }

  void _deleteDrawing() {
    setState(() {
      _currentNote = _currentNote.copyWith(clearDrawing: true);
      _hasChanges = true;
    });
    StorageService.instance.saveOrUpdateNote(_currentNote);
  }

  Future<void> _openTemplatePicker() async {
    final template = await showDialog<NoteTemplate>(
      context: context,
      builder: (ctx) => const TemplatePickerDialog(),
    );

    if (template != null && mounted) {
      setState(() {
        _currentNote = _currentNote.copyWith(
          paperType: template.paperType,
          templateImageBase64: template.backgroundImageBase64,
        );
        if (_titleController.text.trim().isEmpty && template.defaultTitle.isNotEmpty) {
          _titleController.text = template.defaultTitle;
        }
        if (_contentController.text.trim().isEmpty && template.defaultContent.isNotEmpty) {
          _contentController.text = template.defaultContent;
        }
        _hasChanges = true;
      });
      StorageService.instance.saveOrUpdateNote(_currentNote);
    }
  }

  void _openMathAI() {
    showDialog(
      context: context,
      builder: (ctx) => MathAIDialog(
        initialText: _contentController.text.trim(),
        drawingImageBase64: _currentNote.drawingImageBase64,
        onInsertSolution: (solution) {
          setState(() {
            final existing = _contentController.text.trim();
            _contentController.text =
                existing.isNotEmpty ? '$existing\n\n$solution' : solution;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  void _openAudioRecorder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AudioRecorderSheet(
        onTranscriptionComplete: (transcript) {
          setState(() {
            final existing = _contentController.text.trim();
            _contentController.text =
                existing.isNotEmpty ? '$existing\n\n$transcript' : transcript;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  void _insertChecklist() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    const checklistPrefix = '\n[ ] ';

    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, checklistPrefix);
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(
        offset: selection.start + checklistPrefix.length,
      );
    } else {
      _contentController.text = text.isEmpty ? '[ ] ' : '$text$checklistPrefix';
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
    }
    _markChanged();
  }

  void _openChecklistToTasks() {
    showDialog(
      context: context,
      builder: (ctx) => ChecklistToTasksDialog(
        noteContent: _contentController.text,
        noteTitle: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Unbenannte Notiz',
        noteId: _currentNote.id,
      ),
    );
  }

  Future<void> _transcribeHandwriting() async {
    if (_currentNote.drawingImageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Stift-Zeichnung zum Transkribieren vorhanden.')),
      );
      return;
    }

    setState(() => _isAIBusy = true);
    final text = await AIService.instance.transcribeHandwriting(
      _currentNote.drawingImageBase64!,
    );
    setState(() => _isAIBusy = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.text_fields_rounded, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Erkannte Handschrift'),
            ],
          ),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('In Text übernehmen'),
              onPressed: () {
                setState(() {
                  final existing = _contentController.text.trim();
                  _contentController.text =
                      existing.isNotEmpty ? '$existing\n\n$text' : text;
                  _hasChanges = true;
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF1565C0)),
              title: const Text('Aus Galerie wählen'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1565C0)),
              title: const Text('Foto aufnehmen (Kamera)'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _embeddedImages.add(base64Str);
          _hasChanges = true;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'BEnotiz';
    final content = _contentController.text.trim();

    final exportText = '📄 $title (DIN A4 Format)\n\n'
        '$content\n\n'
        '---\nErstellt mit BEnotiz (Android, iOS & Windows)';

    await SharePlus.instance.share(
      ShareParams(
        text: exportText,
        subject: 'PDF Export: $title',
      ),
    );
  }

  void _openShareDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ShareDialog(
        note: _currentNote.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        ),
        onNoteUpdated: (updated) {
          setState(() {
            _currentNote = updated;
            _hasChanges = true;
          });
          StorageService.instance.saveOrUpdateNote(updated);
        },
      ),
    );
  }

  void _showAIMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF1565C0)),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KI-Assistent & Analyse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Wähle eine Aktion für deine Notiz', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.analytics_rounded, color: Color(0xFF2E7D32)),
                  ),
                  title: const Text('Text analysieren & zusammenfassen', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Kernaussagen, Schlagwörter, Aufgaben & Lesbarkeitsindex'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleAIAction('summarize');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.spellcheck_rounded, color: Color(0xFFE65100)),
                  ),
                  title: const Text('Text verbessern & formatieren', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Grammatik, Gliederung und Aufzählungspunkte optimieren'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleAIAction('improve');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE7F6),
                    child: Icon(Icons.checklist_rtl_rounded, color: Color(0xFF512DA8)),
                  ),
                  title: const Text('Aufgaben automatisch extrahieren', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('To-Dos erkennen und direkt in Aufgabenliste übertragen'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleAIAction('extract_tasks');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.calculate_rounded, color: Color(0xFF1565C0)),
                  ),
                  title: const Text('Mathe-KI & Formelrechner', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Formeln lösen, Prozentrechnung, Gleichungen oder Geometrie'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openMathAI();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAIAction(String action) async {
    final text = _contentController.text.trim();
    if (text.isEmpty && action != 'record') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib zuerst Text ein, den die KI analysieren kann.')),
      );
      return;
    }

    setState(() => _isAIBusy = true);

    if (action == 'summarize') {
      final summary = await AIService.instance.summarizeText(text);
      if (mounted) {
        setState(() => _isAIBusy = false);
        _showAIResultDialog('Textanalyse & Zusammenfassung', summary, onAppend: () {
          setState(() {
            _contentController.text = '${_contentController.text}\n\n$summary';
            _hasChanges = true;
          });
        });
      }
    } else if (action == 'extract_tasks') {
      final tasks = await AIService.instance.extractTasksFromText(
        _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Notiz',
        text,
        noteId: _currentNote.id,
      );
      await TaskService.instance.addTasks(tasks);
      if (mounted) {
        setState(() => _isAIBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ ${tasks.length} Aufgabe(n) erkannt und zur Aufgabenliste hinzugefügt!'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (action == 'improve') {
      final improved = await AIService.instance.improveWriting(text);
      if (mounted) {
        setState(() => _isAIBusy = false);
        _showAIResultDialog('Textverbesserung', improved, onAppend: () {
          setState(() {
            _contentController.text = improved;
            _hasChanges = true;
          });
        });
      }
    }
  }

  void _showAIResultDialog(String title, String content, {VoidCallback? onAppend}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF1565C0), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 460),
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(height: 1.45, fontSize: 14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
          if (onAppend != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('In Notiz übernehmen'),
              onPressed: () {
                onAppend();
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuen Tag hinzufügen'),
        content: TextField(
          controller: tagCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'z.B. Arbeit, Idee, Privat',
          ),
          onSubmitted: (_) {
            _addTag(tagCtrl.text.trim());
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              _addTag(tagCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_currentNote.tags.contains(tag)) {
      setState(() {
        _currentNote = _currentNote.copyWith(
          tags: [..._currentNote.tags, tag],
        );
        _hasChanges = true;
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      final updatedTags = List<String>.from(_currentNote.tags)..remove(tag);
      _currentNote = _currentNote.copyWith(tags: updatedTags);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = _currentNote.permission == 'read_only' && _currentNote.isShared;
    final theme = Theme.of(context);

    final dateFormat = DateFormat('dd. MMMM yyyy, HH:mm', 'de_DE');
    String dateStr;
    try {
      dateStr = dateFormat.format(_currentNote.updatedAt);
    } catch (_) {
      dateStr =
          '${_currentNote.updatedAt.day}.${_currentNote.updatedAt.month}.${_currentNote.updatedAt.year}';
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && _hasChanges && !isReadOnly) {
          await _saveNote();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EEF5), // Desk/Table background
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (_hasChanges && !isReadOnly) {
                await _saveNote();
              }
              navigator.pop();
            },
          ),
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'In dieser Notiz suchen...',
                    border: InputBorder.none,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                )
              : Row(
                  children: [
                    const BENotizLogo(size: 28),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0E4FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DIN A4',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentNote.paperType.toUpperCase(),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
          actions: [
            // Tastatur anfordern / ausblenden Button (Stift-Modus)
            if (!isReadOnly)
              IconButton(
                icon: Icon(
                  _keyboardEnabled ? Icons.keyboard_hide_rounded : Icons.keyboard_outlined,
                  color: _keyboardEnabled ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                ),
                tooltip: _keyboardEnabled
                    ? 'Tastatur ausblenden (Stift-Modus)'
                    : 'Tastatur einblenden (Tipp-Modus)',
                onPressed: _toggleKeyboard,
              ),

            // A4 Vorlage wählen / hochladen
            IconButton(
              icon: const Icon(Icons.style_rounded, color: Color(0xFF1565C0)),
              tooltip: 'A4 Vorlage wählen oder hochladen',
              onPressed: _openTemplatePicker,
            ),

            // Search in note toggle
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              tooltip: _isSearching ? 'Suche schließen' : 'In Notiz suchen',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),

            if (_isAIBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),

            // Pin Toggle
            IconButton(
              icon: Icon(
                _currentNote.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _currentNote.isPinned ? theme.colorScheme.primary : null,
              ),
              tooltip: _currentNote.isPinned ? 'Notiz lösen' : 'Notiz anheften',
              onPressed: () {
                setState(() {
                  _currentNote = _currentNote.copyWith(isPinned: !_currentNote.isPinned);
                  _hasChanges = true;
                });
              },
            ),

            // Share / Invite Button
            IconButton(
              icon: Icon(
                _currentNote.isShared ? Icons.share_rounded : Icons.share_outlined,
                color: _currentNote.isShared ? Colors.blue : null,
              ),
              tooltip: 'Per Link teilen & einladen',
              onPressed: _openShareDialog,
            ),

            // Color Palette Picker
            PopupMenuButton<int>(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Farbe ändern',
              onSelected: (colorVal) {
                setState(() {
                  _currentNote = _currentNote.copyWith(colorValue: colorVal);
                  _hasChanges = true;
                });
              },
              itemBuilder: (ctx) {
                return _colorPalette.map((colVal) {
                  return PopupMenuItem<int>(
                    value: colVal,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(colVal),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(colVal == _currentNote.colorValue ? 'Ausgewählt' : 'Farbe'),
                      ],
                    ),
                  );
                }).toList();
              },
            ),

            // Delete Action
            if (widget.note != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Notiz löschen',
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Notiz löschen?'),
                      content:
                          const Text('Möchtest du diese Notiz wirklich unwiderruflich löschen?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Abbrechen'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Löschen', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await StorageService.instance.deleteNote(_currentNote.id);
                    navigator.pop();
                  }
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // In-note search indicator banner
                  if (_isSearching && _searchQuery.isNotEmpty)
                    Container(
                      color: const Color(0xFFD0E4FF),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 16, color: Color(0xFF1565C0)),
                          const SizedBox(width: 8),
                          Text(
                            'Suche nach "$_searchQuery" (${RegExp(RegExp.escape(_searchQuery), caseSensitive: false).allMatches(_contentController.text).length} Treffer)',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  // Read-only indicator banner
                  if (isReadOnly)
                    Container(
                      color: Colors.orange.shade100,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 16, color: Colors.orange.shade900),
                          const SizedBox(width: 8),
                          Text(
                            'Nur-Lese-Modus (Geteilte Notiz)',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  // Tags row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ..._currentNote.tags.map((tag) => Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: InputChip(
                                        label: Text('#$tag'),
                                        onDeleted: isReadOnly ? null : () => _removeTag(tag),
                                      ),
                                    )),
                                if (!isReadOnly)
                                  ActionChip(
                                    avatar: const Icon(Icons.add, size: 16),
                                    label: const Text('Tag'),
                                    onPressed: _showAddTagDialog,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stylus / Keyboard Mode Banner (Lenovo Pen support: Tastatur erst nach Klick)
                  if (!isReadOnly)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _keyboardEnabled ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _keyboardEnabled ? const Color(0xFFA5D6A7) : const Color(0xFF90CAF9),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _keyboardEnabled ? Icons.keyboard_rounded : Icons.draw_rounded,
                            size: 20,
                            color: _keyboardEnabled ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _keyboardEnabled
                                      ? '⌨️ Tastatur aktiv (Tipp-Modus)'
                                      : '✍️ Stift-Modus aktiv (Lenovo Pen)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _keyboardEnabled ? const Color(0xFF1B5E20) : const Color(0xFF0D47A1),
                                  ),
                                ),
                                Text(
                                  _keyboardEnabled
                                      ? 'Tastatur ist aktiv. Tippe auf "Stift-Modus" zum Ausblenden.'
                                      : 'Tastatur ist gesperrt. Tippe auf "Tastatur aktivieren" zum Tippen.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _keyboardEnabled ? Colors.green.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (!_keyboardEnabled)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('Zeichnen', style: TextStyle(fontSize: 11)),
                              onPressed: _openStylusCanvas,
                            ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _keyboardEnabled ? Colors.white : const Color(0xFF1565C0),
                              foregroundColor: _keyboardEnabled ? const Color(0xFF2E7D32) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(
                              _keyboardEnabled ? Icons.draw_rounded : Icons.keyboard_rounded,
                              size: 15,
                            ),
                            label: Text(
                              _keyboardEnabled ? 'Stift-Modus' : 'Tastatur aktivieren',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _toggleKeyboard,
                          ),
                        ],
                      ),
                    ),

                  // Title & Body in authentic DIN A4 Paper Sheet
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: A4PaperSheet(
                        paperType: _currentNote.paperType,
                        backgroundImageBase64: _currentNote.templateImageBase64,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _titleController,
                              focusNode: _titleFocusNode,
                              readOnly: isReadOnly || !_keyboardEnabled,
                              onTap: () {
                                if (!_keyboardEnabled && !isReadOnly) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✍️ Stift-Modus aktiv: Tastatur ist gesperrt. Tippe oben auf "Tastatur aktivieren", um mit Tastatur zu schreiben.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D253F),
                              ),
                              decoration: InputDecoration(
                                hintText: _keyboardEnabled ? 'Titel der Notiz...' : '✍️ Titel (Tastatur oben aktivieren zum Editieren)...',
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                            ),
                            const Divider(color: Color(0xFFE2E8F0), height: 20),
                            TextField(
                              controller: _contentController,
                              focusNode: _contentFocusNode,
                              readOnly: isReadOnly || !_keyboardEnabled,
                              onTap: () {
                                if (!_keyboardEnabled && !isReadOnly) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✍️ Stift-Modus aktiv: Tastatur ist gesperrt. Tippe oben auf "Tastatur aktivieren", um mit Tastatur zu schreiben.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Color(0xFF1E293B),
                              ),
                              decoration: InputDecoration(
                                hintText: _keyboardEnabled
                                    ? 'Schreibe hier, füge Checklisten ein [ ], nutze den Tablet-Stift oder die Menüleiste...'
                                    : '✍️ Stift-Modus aktiv (Lenovo Pen). Nutze "Zeichnen" oder aktiviere oben die Tastatur zum Tippen...',
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                            ),

                            // Embedded Images preview
                            if (_embeddedImages.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _embeddedImages.map((base64) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          base64Decode(base64),
                                          width: 180,
                                          height: 180,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _embeddedImages.remove(base64);
                                              _hasChanges = true;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],

                            // Hand-drawn sketch preview if available
                            if (_currentNote.drawingImageBase64 != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black.withAlpha(25)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(8),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.draw_rounded,
                                                  size: 18, color: Color(0xFF1565C0)),
                                              SizedBox(width: 8),
                                              Text(
                                                'Stift-Zeichnung / Handschrift',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              TextButton.icon(
                                                onPressed: _openStylusCanvas,
                                                icon: const Icon(Icons.edit_rounded, size: 16),
                                                label: const Text('Bearbeiten & Zoomen'),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 18),
                                                tooltip: 'Zeichnung entfernen',
                                                onPressed: _deleteDrawing,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    InkWell(
                                      onTap: _openStylusCanvas,
                                      child: Container(
                                        constraints: const BoxConstraints(maxHeight: 340),
                                        color: Colors.white,
                                        child: Center(
                                          child: Image.memory(
                                            base64Decode(_currentNote.drawingImageBase64!),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (!_keyboardEnabled) ...[
                              const SizedBox(height: 20),
                              InkWell(
                                onTap: _openStylusCanvas,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD).withAlpha(140),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF90CAF9), width: 1.5),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1565C0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.draw_rounded, color: Colors.white, size: 28),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        '✍️ Tippen zum Schreiben mit dem Stift',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1)),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Lenovo Pen / Stylus schreiben sofort • Finger zoomen & verschieben die Notiz',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer: Last modified date & info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.black.withAlpha(15))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Zuletzt bearbeitet: $dateStr',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (_currentNote.isShared)
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentNote.collaborators.length} Teilnehmer',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // FREI VERSCHIEBBARE WERKZEUGLEISTE (Draggable Tool Dock)
              DraggableToolDock(
                keyboardEnabled: _keyboardEnabled,
                onToggleKeyboard: isReadOnly ? null : _toggleKeyboard,
                onOpenStylus: _openStylusCanvas,
                onOpenMathAI: _openMathAI,
                onOpenAudio: _openAudioRecorder,
                onInsertImage: _pickImage,
                onInsertChecklist: _insertChecklist,
                onExportTasks: _openChecklistToTasks,
                onTranscribeHandwriting: _transcribeHandwriting,
                onExportPdf: _exportPdf,
                onSearch: () {
                  setState(() => _isSearching = !_isSearching);
                },
                onOpenAI: _showAIMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
