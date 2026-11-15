import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../screens/note_edit_screen.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import 'a4_paper_sheet.dart';
import 'audio_recorder_sheet.dart';
import 'checklist_to_tasks_dialog.dart';
import 'draggable_tool_dock.dart';
import 'math_ai_dialog.dart';

enum PenStyle {
  ballpoint, // Kugelschreiber / Fineliner
  fountain, // Füllfederhalter / Kalligraphie
  pencil, // Bleistift
  brush, // Pinsel
  highlighter, // Textmarker
  dashed, // Gestrichelte Linie
  dotted, // Gepunktete Linie
}

class DrawingPoint {
  final Offset offset;
  final double pressure;

  DrawingPoint({required this.offset, this.pressure = 1.0});

  Map<String, dynamic> toMap() => {'x': offset.dx, 'y': offset.dy, 'p': pressure};

  factory DrawingPoint.fromMap(Map<String, dynamic> map) => DrawingPoint(
        offset: Offset((map['x'] as num).toDouble(), (map['y'] as num).toDouble()),
        pressure: (map['p'] as num?)?.toDouble() ?? 1.0,
      );
}

class DrawingStroke {
  final List<DrawingPoint> points;
  final Color color;
  final double width;
  final PenStyle penStyle;
  final bool isEraser;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    this.penStyle = PenStyle.ballpoint,
    this.isEraser = false,
  });

  Map<String, dynamic> toMap() => {
        'points': points.map((p) => p.toMap()).toList(),
        'color': color.toARGB32(),
        'width': width,
        'style': penStyle.name,
        'isEraser': isEraser,
      };

  factory DrawingStroke.fromMap(Map<String, dynamic> map) {
    PenStyle style = PenStyle.ballpoint;
    if (map['isHighlighter'] == true || map['style'] == 'highlighter') {
      style = PenStyle.highlighter;
    } else if (map['style'] != null) {
      style = PenStyle.values.firstWhere(
        (e) => e.name == map['style'],
        orElse: () => PenStyle.ballpoint,
      );
    }

    return DrawingStroke(
      points: (map['points'] as List).map((p) => DrawingPoint.fromMap(p)).toList(),
      color: Color(map['color'] as int),
      width: (map['width'] as num).toDouble(),
      penStyle: style,
      isEraser: map['isEraser'] as bool? ?? false,
    );
  }
}

/// GestureRecognizer, der Stift- und Stylus-Eingaben (Lenovo Pen) in der Gesture Arena
/// sofort für das Zeichnen beansprucht.
/// Verhindert zu 100%, dass das übergeordnete InteractiveViewer beim Schreiben mit dem Stift
/// die Seite ungewollt verschiebt oder pannt.
/// Finger-Gesten (Touch) werden durchgelassen, damit Pinch-to-Zoom und Verschieben mit den Fingern
/// butterweich funktionieren.
class StylusPanBlockerGestureRecognizer extends OneSequenceGestureRecognizer {
  final bool Function()? isStylusActive;
  final bool Function()? fingerDrawingEnabled;
  final bool Function()? isPanMode;

  StylusPanBlockerGestureRecognizer({
    this.isStylusActive,
    this.fingerDrawingEnabled,
    this.isPanMode,
    super.debugOwner,
  });

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    // Wenn der Verschieben-Modus (Hand-Tool) aktiv ist: Finger und Maus dürfen die Seite verschieben
    if ((isPanMode?.call() ?? false) &&
        (event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.mouse)) {
      return false; // Weiterreichen an InteractiveViewer zum Verschieben
    }

    // 1. Wenn Finger-Zeichnen manuell eingeschaltet wurde: Finger zeichnen auch und dürfen die Seite nicht verschieben
    if (fingerDrawingEnabled?.call() == true) {
      return true;
    }

    // 2. STIFT (Lenovo Pen / Stylus / Inverted Stylus):
    // Stifte dürfen NIEMALS die Seite bewegen! Sie müssen immer sofort akzeptiert werden,
    // damit das übergeordnete InteractiveViewer (ScaleGestureRecognizer) die Geste verliert.
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return true;
    }

    // 3. Maus (für Desktop/Web): Primäre Maustaste auf dem Papier zeichnet und verschiebt nicht
    if (event.kind == PointerDeviceKind.mouse && event.buttons == kPrimaryMouseButton) {
      return true;
    }

    // 4. Palm Rejection & Ein-Finger-Schreibschutz: Im Stift-Schreibmodus wird 1-Finger/Handballen-Touch
    // abgefangen, damit die aufliegende Hand das Blatt keinesfalls ungewollt mitzieht!
    if (event.kind == PointerDeviceKind.touch) {
      return true;
    }

    return false;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'StylusPanBlockerGestureRecognizer';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void handleEvent(PointerEvent event) {}
}

class StylusCanvasScreen extends StatefulWidget {
  final Note? note;
  final String? title;
  final String? initialDrawingData;
  final String paperType;
  final Function(String strokeDataJson, String imageBase64) onSave;

  const StylusCanvasScreen({
    super.key,
    this.note,
    this.title,
    this.initialDrawingData,
    this.paperType = 'blank',
    required this.onSave,
  });

  @override
  State<StylusCanvasScreen> createState() => _StylusCanvasScreenState();
}

class _StylusCanvasScreenState extends State<StylusCanvasScreen> {
  final List<DrawingStroke> _strokes = [];
  final List<List<DrawingStroke>> _undoStack = [];
  final List<List<DrawingStroke>> _redoStack = [];
  DrawingStroke? _currentStroke;

  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  bool _fingerDrawingEnabled = false; // Standardmäßig: Finger zoomen & verschieben, nur Stift zeichnet!

  Color _selectedColor = const Color(0xFF1565C0); // BEnotiz Blue
  double _strokeWidth = 3.5;
  PenStyle _selectedStyle = PenStyle.ballpoint;
  bool _isEraser = false;
  String _eraserMode = 'object'; // 'object' (Ganze Striche) oder 'precision' (Teil-Striche)
  double _eraserRadius = 24.0;
  Offset? _currentEraserPos;
  final bool _stylusOnlyMode = true; // Palm rejection ist standardmäßig aktiv!
  int _activeStylusCount = 0; // Zählt aktive Stift-Berührungen auf dem Blatt
  bool _isPanMode = false; // Standardmäßig Stift-Schreibmodus: Blatt ist bombenfest verankert!

  // Ruler state
  bool _showRuler = false;
  String _rulerMode = 'straight'; // 'straight' (Lineal), 'triangle' (Geodreieck), 'circle' (Zirkel)
  Offset _rulerPos = const Offset(180, 260);
  double _rulerAngle = 0.0; // In radians
  final double _rulerLength = 340.0;
  final double _circleRadius = 80.0;

  final List<Color> _penColors = const [
    Color(0xFF1565C0), // Royal Blue
    Color(0xFF0D253F), // Midnight Navy
    Color(0xFF212121), // Charcoal Black
    Color(0xFFD32F2F), // Red
    Color(0xFF2E7D32), // Emerald Green
    Color(0xFFF57C00), // Orange
    Color(0xFFFDD835), // Marker Yellow
    Color(0xFF7B1FA2), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onZoomChanged);
    _loadInitialStrokes();
  }

  void _onZoomChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.03) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _zoomTo(double targetScale) {
    setState(() {
      _currentScale = targetScale;
      _transformationController.value = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _loadInitialStrokes() {
    if (widget.initialDrawingData != null && widget.initialDrawingData!.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(widget.initialDrawingData!);
        final loaded = decoded
            .map((item) => DrawingStroke.fromMap(item as Map<String, dynamic>))
            .where((s) => !s.isEraser) // Legacy-Radierer-Striche herausfiltern
            .toList();
        _strokes.addAll(loaded);
      } catch (_) {}
    }
  }

  void _pushUndoSnapshot() {
    _undoStack.add(_strokes
        .map((s) => DrawingStroke(
              points: List.from(s.points),
              color: s.color,
              width: s.width,
              penStyle: s.penStyle,
              isEraser: s.isEraser,
            ))
        .toList());
    _redoStack.clear();
    if (_undoStack.length > 40) {
      _undoStack.removeAt(0);
    }
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final l2 = (b - a).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    final t = max(0.0, min(1.0, ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2));
    final projection = Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
    return (p - projection).distance;
  }

  bool _strokeIntersectsPoint(DrawingStroke stroke, Offset p, double radius) {
    if (stroke.points.isEmpty) return false;
    final threshold = radius + (stroke.width / 2);
    if (stroke.points.length == 1) {
      return (stroke.points.first.offset - p).distance <= threshold;
    }
    for (int i = 1; i < stroke.points.length; i++) {
      if (_distToSegment(p, stroke.points[i - 1].offset, stroke.points[i].offset) <= threshold) {
        return true;
      }
    }
    return false;
  }

  void _eraseAt(Offset pos) {
    _currentEraserPos = pos;
    final radius = _eraserRadius;
    bool modified = false;

    if (_eraserMode == 'object') {
      // Objekt-Radierer: Ganze berührte Striche sauber entfernen (Vorlagenlinien bleiben 100% erhalten)
      final remaining = <DrawingStroke>[];
      for (final stroke in _strokes) {
        if (_strokeIntersectsPoint(stroke, pos, radius)) {
          modified = true;
        } else {
          remaining.add(stroke);
        }
      }
      if (modified) {
        setState(() {
          _strokes.clear();
          _strokes.addAll(remaining);
        });
      }
    } else {
      // Präzisions-Radierer: Striche an Berührungspunkten teilen / abschneiden
      final updatedStrokes = <DrawingStroke>[];
      for (final stroke in _strokes) {
        if (!_strokeIntersectsPoint(stroke, pos, radius)) {
          updatedStrokes.add(stroke);
          continue;
        }
        modified = true;
        final pieces = <List<DrawingPoint>>[];
        var currentPiece = <DrawingPoint>[];
        for (final pt in stroke.points) {
          if ((pt.offset - pos).distance > radius) {
            currentPiece.add(pt);
          } else {
            if (currentPiece.length >= 2) {
              pieces.add(currentPiece);
            }
            currentPiece = <DrawingPoint>[];
          }
        }
        if (currentPiece.length >= 2) {
          pieces.add(currentPiece);
        }

        for (final piece in pieces) {
          updatedStrokes.add(DrawingStroke(
            points: piece,
            color: stroke.color,
            width: stroke.width,
            penStyle: stroke.penStyle,
          ));
        }
      }
      if (modified) {
        setState(() {
          _strokes.clear();
          _strokes.addAll(updatedStrokes);
        });
      }
    }
  }

  Offset _applyRulerSnapping(Offset point) {
    if (!_showRuler) return point;

    if (_rulerMode == 'circle') {
      final dist = (point - _rulerPos).distance;
      if ((dist - _circleRadius).abs() <= 32.0) {
        final angle = atan2(point.dy - _rulerPos.dy, point.dx - _rulerPos.dx);
        return Offset(
          _rulerPos.dx + _circleRadius * cos(angle),
          _rulerPos.dy + _circleRadius * sin(angle),
        );
      }
      return point;
    }

    // Straight ruler or Geodreieck straight edge
    final halfLen = _rulerLength / 2;
    final cosA = cos(_rulerAngle);
    final sinA = sin(_rulerAngle);

    // Ruler edge line segment A -> B (upper edge)
    final normal = Offset(-sinA, cosA) * 24.0;
    final a = Offset(_rulerPos.dx - halfLen * cosA, _rulerPos.dy - halfLen * sinA) - normal;
    final b = Offset(_rulerPos.dx + halfLen * cosA, _rulerPos.dy + halfLen * sinA) - normal;

    final ab = b - a;
    final ap = point - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0) return point;

    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    if (t >= -0.05 && t <= 1.05) {
      final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
      if ((point - proj).distance <= 32.0) {
        return proj;
      }
    }

    return point;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      if (_isPanMode) {
        setState(() => _isPanMode = false);
      }
      _activeStylusCount++;
    }

    // Wenn der Verschieben-Modus aktiv ist, keine Striche zeichnen
    if (_isPanMode) {
      return;
    }

    // Palm Rejection: Finger-Berührung (PointerDeviceKind.touch) darf KEINE Striche erzeugen!
    // Finger sind ausschließlich für Pinch-to-Zoom und Verschieben reserviert.
    if (!_fingerDrawingEnabled && event.kind == PointerDeviceKind.touch) {
      return;
    }

    if (_stylusOnlyMode &&
        event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus &&
        event.kind != PointerDeviceKind.mouse) {
      return;
    }

    final isHardwareEraser = event.kind == PointerDeviceKind.invertedStylus || _isEraser;

    if (isHardwareEraser) {
      _pushUndoSnapshot();
      setState(() {
        _eraseAt(event.localPosition);
      });
      return;
    }

    final snappedPos = _applyRulerSnapping(event.localPosition);
    _pushUndoSnapshot();

    setState(() {
      _currentStroke = DrawingStroke(
        points: [DrawingPoint(offset: snappedPos, pressure: event.pressure)],
        color: _selectedStyle == PenStyle.highlighter
            ? _selectedColor.withAlpha(85)
            : _selectedColor,
        width: _selectedStyle == PenStyle.highlighter ? 22.0 : _strokeWidth,
        penStyle: _selectedStyle,
        isEraser: false,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isPanMode) return;
    if (!_fingerDrawingEnabled && event.kind == PointerDeviceKind.touch) {
      return;
    }

    final isHardwareEraser = event.kind == PointerDeviceKind.invertedStylus || _isEraser;

    if (isHardwareEraser) {
      setState(() {
        _eraseAt(event.localPosition);
      });
      return;
    }

    if (_currentStroke == null) return;
    final snappedPos = _applyRulerSnapping(event.localPosition);
    setState(() {
      _currentStroke!.points.add(DrawingPoint(
        offset: snappedPos,
        pressure: event.pressure > 0 ? event.pressure : 1.0,
      ));
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      _activeStylusCount = max(0, _activeStylusCount - 1);
    }

    if (_isPanMode) return;
    if (!_fingerDrawingEnabled && event.kind == PointerDeviceKind.touch) {
      return;
    }

    final isHardwareEraser = event.kind == PointerDeviceKind.invertedStylus || _isEraser;

    if (isHardwareEraser) {
      setState(() {
        _currentEraserPos = null;
      });
      return;
    }

    if (_currentStroke == null) return;
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      _activeStylusCount = max(0, _activeStylusCount - 1);
    }
    if (_currentStroke != null) {
      setState(() {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
      });
    }
  }

  void _undo() {
    if (_undoStack.isNotEmpty) {
      setState(() {
        _redoStack.add(_strokes
            .map((s) => DrawingStroke(
                  points: List.from(s.points),
                  color: s.color,
                  width: s.width,
                  penStyle: s.penStyle,
                  isEraser: s.isEraser,
                ))
            .toList());
        _strokes.clear();
        _strokes.addAll(_undoStack.removeLast());
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        _undoStack.add(_strokes
            .map((s) => DrawingStroke(
                  points: List.from(s.points),
                  color: s.color,
                  width: s.width,
                  penStyle: s.penStyle,
                  isEraser: s.isEraser,
                ))
            .toList());
        _strokes.clear();
        _strokes.addAll(_redoStack.removeLast());
      });
    }
  }

  void _clearCanvas() {
    if (_strokes.isEmpty) return;
    _pushUndoSnapshot();
    setState(() {
      _strokes.clear();
    });
  }

  Future<String> _renderCanvasToBase64() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const canvasSize = Size(900, 1200);

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height), bgPaint);

    if (widget.paperType != 'blank') {
      A4PaperPainter(paperType: widget.paperType).paint(canvas, canvasSize);
    }

    final painter = StylusCanvasPainter(strokes: _strokes, currentStroke: null);
    painter.paint(canvas, canvasSize);

    final picture = recorder.endRecording();
    String base64Image = '';
    try {
      final img = await picture.toImage(canvasSize.width.toInt(), canvasSize.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        base64Image = base64Encode(byteData.buffer.asUint8List());
      }
    } catch (_) {}
    return base64Image;
  }

  Future<void> _saveAndExit() async {
    if (_strokes.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final strokeJson = json.encode(_strokes.map((s) => s.toMap()).toList());
    final base64Image = await _renderCanvasToBase64();

    widget.onSave(strokeJson, base64Image);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleKeyboard() async {
    final strokeJson = json.encode(_strokes.map((s) => s.toMap()).toList());
    final base64Image = await _renderCanvasToBase64();
    widget.onSave(strokeJson, base64Image);

    if (!mounted) return;

    if (widget.note != null) {
      final updatedNote = widget.note!.copyWith(
        drawingData: strokeJson,
        drawingImageBase64: base64Image,
        updatedAt: DateTime.now(),
      );
      await StorageService.instance.saveOrUpdateNote(updatedNote);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (ctx) => NoteEditScreen(
              note: updatedNote,
              autoFocusKeyboard: true,
            ),
          ),
        );
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _openStylus() {
    setState(() {
      _isEraser = false;
      _isPanMode = false;
      _selectedStyle = PenStyle.ballpoint;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✍️ Stift ausgewählt (Lenovo Pen / Stylus)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openMathAI() async {
    final imageBase64 = await _renderCanvasToBase64();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => MathAIDialog(
        initialText: widget.title,
        drawingImageBase64: imageBase64.isNotEmpty ? imageBase64 : null,
        onInsertSolution: (solution) {
          _showSolutionDialog(solution);
        },
      ),
    );
  }

  void _showSolutionDialog(String solution) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.calculate_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Mathe-KI Lösung'),
          ],
        ),
        content: SelectableText(solution),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
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
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.mic_rounded, color: Color(0xFF1565C0)),
                  SizedBox(width: 8),
                  Text('Audio-Transkript'),
                ],
              ),
              content: SelectableText(transcript),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Schließen'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _insertChecklist() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.checklist_rounded, color: Color(0xFF66BB6A)),
            SizedBox(width: 8),
            Text('Checkliste / Aufgabe hinzufügen'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Füge einen Checklisten-Punkt ein, der direkt mit der Aufgabenliste synchronisiert werden kann:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'z.B. Dokumente überprüfen...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixText: '[ ] ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final val = textCtrl.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty && widget.note != null) {
                final existingContent = widget.note!.content;
                final updatedContent = existingContent.isEmpty
                    ? '[ ] $val'
                    : '$existingContent\n[ ] $val';
                final updatedNote = widget.note!.copyWith(
                  content: updatedContent,
                  updatedAt: DateTime.now(),
                );
                await StorageService.instance.saveOrUpdateNote(updatedNote);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Checkliste hinzugefügt: [ ] $val'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  Future<void> _openChecklistToTasks() async {
    String content = widget.note?.content ?? '';
    if (_strokes.isNotEmpty) {
      final img = await _renderCanvasToBase64();
      if (img.isNotEmpty) {
        final ocr = await AIService.instance.transcribeHandwriting(img);
        if (ocr.isNotEmpty) {
          content = content.isNotEmpty ? '$content\n$ocr' : ocr;
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => ChecklistToTasksDialog(
        noteContent: content,
        noteTitle: widget.title ?? widget.note?.title ?? 'Notiz',
        noteId: widget.note?.id ?? 'canvas_note',
      ),
    );
  }

  Future<void> _transcribeHandwriting() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Stift-Zeichnung zum Transkribieren vorhanden.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Handschrift wird mit KI in Druckschrift umgewandelt...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final img = await _renderCanvasToBase64();
    final text = await AIService.instance.transcribeHandwriting(img);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.text_fields_rounded, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Erkannte Handschrift'),
            ],
          ),
          content: SelectableText(text.isNotEmpty ? text : 'Keine Schrift erkannt.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
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
      if (picked != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bild "${picked.name}" ausgewählt.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    final title = widget.title ?? widget.note?.title ?? 'BEnotiz';
    final content = widget.note?.content ?? '';

    final exportText = '📄 $title (DIN A4 Stift-Notiz)\n\n'
        '$content\n\n'
        '---\nErstellt mit BEnotiz (Lenovo Pen / Stylus)';

    await SharePlus.instance.share(
      ShareParams(
        text: exportText,
        subject: 'PDF Export: $title',
      ),
    );
  }

  void _searchInNote() {
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('In Notiz suchen'),
          ],
        ),
        content: TextField(
          controller: searchCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Suchbegriff eingeben...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _showAIMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
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
                          Text('Wähle eine KI-Aktion für deine Notiz', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  title: const Text('Text & Handschrift analysieren & zusammenfassen', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Kernaussagen, Schlagwörter & Zusammenfassung'),
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
                  subtitle: const Text('Grammatik, Gliederung und Lesbarkeit optimieren'),
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
                    _openChecklistToTasks();
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
    String text = widget.note?.content ?? '';
    if (_strokes.isNotEmpty) {
      final img = await _renderCanvasToBase64();
      final ocr = await AIService.instance.transcribeHandwriting(img);
      if (ocr.isNotEmpty) {
        text = text.isNotEmpty ? '$text\n$ocr' : ocr;
      }
    }

    if (text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kein Text oder keine Handschrift zum Analysieren vorhanden.')),
        );
      }
      return;
    }

    if (action == 'summarize') {
      final summary = await AIService.instance.summarizeText(text);
      if (mounted) {
        _showAIResultDialog('Textanalyse & Zusammenfassung', summary);
      }
    } else if (action == 'improve') {
      final improved = await AIService.instance.improveWriting(text);
      if (mounted) {
        _showAIResultDialog('Optimierter Text', improved);
      }
    }
  }

  void _showAIResultDialog(String title, String content) {
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
            child: SelectableText(content, style: const TextStyle(height: 1.45, fontSize: 14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.draw_rounded, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                widget.title != null && widget.title!.isNotEmpty
                    ? widget.title!
                    : 'A4 Stift-Notiz',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD0E4FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.paperType.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
              ),
            ),
          ],
        ),
        actions: [
          // Zoom out (-)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
            tooltip: 'Herauszoomen (-)',
            onPressed: () {
              final newScale = max(0.5, _currentScale - 0.2);
              _zoomTo(newScale);
            },
          ),

          // Zoom level indicator and reset to 100%
          InkWell(
            onTap: () => _zoomTo(1.0),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD0E4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_in_rounded, size: 15, color: Color(0xFF1565C0)),
                  const SizedBox(width: 4),
                  Text(
                    '${(_currentScale * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1565C0)),
                  ),
                ],
              ),
            ),
          ),

          // Zoom in (+)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            tooltip: 'Hineinzoomen (+)',
            onPressed: () {
              final newScale = min(3.5, _currentScale + 0.2);
              _zoomTo(newScale);
            },
          ),
          const SizedBox(width: 4),

          // Palm Rejection & Finger Mode Toggle Button
          Tooltip(
            message: _fingerDrawingEnabled
                ? 'Finger-Zeichnen aktiv (Tippen für Palm-Rejection & Zoom)'
                : 'Palm-Rejection aktiv: Finger zoomen/verschieben, nur Stift zeichnet',
            child: IconButton(
              icon: Icon(
                _fingerDrawingEnabled ? Icons.touch_app_rounded : Icons.pinch_rounded,
                color: _fingerDrawingEnabled ? Colors.orange : const Color(0xFF1565C0),
              ),
              onPressed: () {
                setState(() => _fingerDrawingEnabled = !_fingerDrawingEnabled);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _fingerDrawingEnabled
                          ? '👉 Finger-Zeichnen eingeschaltet'
                          : '✋ Finger-Zoom & Verschieben aktiv (Stift zeichnet)',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),

          // Lineal Toggle
          IconButton(
            icon: Icon(
              Icons.straighten_rounded,
              color: _showRuler ? const Color(0xFF1565C0) : Colors.grey.shade700,
            ),
            tooltip: _showRuler ? 'Lineal ausblenden' : 'Lineal einblenden',
            onPressed: () => setState(() => _showRuler = !_showRuler),
          ),
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Rückgängig',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Wiederholen',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Alles löschen',
            onPressed: _strokes.isNotEmpty ? _clearCanvas : null,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _saveAndExit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Speichern'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Tool, Pen Styles & Colors Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FC),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Hand / Verschieben Tool Toggle (Blatt mit Fingern/Maus bewegen)
                      InkWell(
                        onTap: () => setState(() {
                          _isPanMode = !_isPanMode;
                          if (_isPanMode) _isEraser = false;
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isPanMode ? const Color(0xFFD0E4FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isPanMode ? const Color(0xFF1565C0) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.pan_tool_rounded,
                                size: 16,
                                color: _isPanMode ? const Color(0xFF1565C0) : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Verschieben',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _isPanMode ? FontWeight.bold : FontWeight.w600,
                                  color: _isPanMode ? const Color(0xFF1565C0) : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const VerticalDivider(width: 12),

                      // Pen Styles Selector
                      _penStyleButton(PenStyle.ballpoint, Icons.edit_rounded, 'Kugelschreiber'),
                      _penStyleButton(PenStyle.fountain, Icons.history_edu_rounded, 'Füllfederhalter'),
                      _penStyleButton(PenStyle.pencil, Icons.mode_edit_outline_rounded, 'Bleistift'),
                      _penStyleButton(PenStyle.brush, Icons.brush_rounded, 'Pinsel'),
                      _penStyleButton(PenStyle.highlighter, Icons.format_color_fill_rounded, 'Textmarker'),
                      _penStyleButton(PenStyle.dashed, Icons.line_style_rounded, 'Gestrichelt'),
                      _penStyleButton(PenStyle.dotted, Icons.more_horiz_rounded, 'Gepunktet'),

                      const SizedBox(width: 10),
                      const VerticalDivider(width: 16),
                      const SizedBox(width: 4),

                      // Eraser Toggle
                      InkWell(
                        onTap: () => setState(() {
                          _isEraser = !_isEraser;
                          if (_isEraser) _isPanMode = false;
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isEraser ? const Color(0xFFD0E4FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isEraser ? const Color(0xFF1565C0) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_fix_normal_rounded,
                                size: 18,
                                color: _isEraser ? const Color(0xFF1565C0) : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Radierer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isEraser ? const Color(0xFF1565C0) : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Eraser Options (Mode & Radius)
                      if (_isEraser) ...[
                        InkWell(
                          onTap: () => setState(() => _eraserMode = _eraserMode == 'object' ? 'precision' : 'object'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1565C0)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _eraserMode == 'object' ? Icons.select_all_rounded : Icons.content_cut_rounded,
                                  size: 15,
                                  color: const Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _eraserMode == 'object' ? 'Ganze Striche' : 'Präzision',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Eraser radius buttons
                        Row(
                          children: [14.0, 24.0, 40.0].map((r) {
                            final isSelected = _eraserRadius == r;
                            return InkWell(
                              onTap: () => setState(() => _eraserRadius = r),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Container(
                                  width: r == 14.0 ? 12 : (r == 24.0 ? 18 : 24),
                                  height: r == 14.0 ? 12 : (r == 24.0 ? 18 : 24),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(width: 12),
                        // Badge: Vorlagenlinien geschützt
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_rounded, size: 14, color: Colors.green.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Vorlagenlinien geschützt',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Stroke Width selector (2, 4, 7, 12 px)
                      if (!_isEraser && _selectedStyle != PenStyle.highlighter) ...[
                        Row(
                          children: [2.0, 3.5, 6.0, 10.0].map((w) {
                            final isSelected = _strokeWidth == w;
                            return InkWell(
                              onTap: () => setState(() => _strokeWidth = w),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Container(
                                  width: w + 6,
                                  height: w + 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(width: 14),
                      ],

                      // Color Palette
                      if (!_isEraser)
                        Row(
                          children: _penColors.map((color) {
                            final isSelected = _selectedColor == color;
                            return InkWell(
                              onTap: () => setState(() => _selectedColor = color),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade400,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              // Interactive Stylus Drawing Canvas with A4 background & Pinch-to-Zoom
              Expanded(
                child: Container(
                  color: const Color(0xFFE8EEF5), // Schreibtisch-Hintergrund
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 3.5,
                    boundaryMargin: const EdgeInsets.all(500),
                    panEnabled: _isPanMode,
                    scaleEnabled: true,
                    child: RawGestureDetector(
                      gestures: {
                        StylusPanBlockerGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<StylusPanBlockerGestureRecognizer>(
                          () => StylusPanBlockerGestureRecognizer(
                            isStylusActive: () => _activeStylusCount > 0,
                            fingerDrawingEnabled: () => _fingerDrawingEnabled,
                            isPanMode: () => _isPanMode,
                          ),
                          (StylusPanBlockerGestureRecognizer instance) {},
                        ),
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 860,
                        height: 1220,
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Listener(
                          key: const Key('stylus_drawing_canvas'),
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: _onPointerDown,
                          onPointerMove: _onPointerMove,
                          onPointerUp: _onPointerUp,
                          onPointerCancel: _onPointerCancel,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: A4PaperPainter(paperType: widget.paperType),
                                foregroundPainter: StylusCanvasPainter(
                                  strokes: _strokes,
                                  currentStroke: _currentStroke,
                                ),
                                size: const Size(860, 1220),
                              ),
                              if (widget.title != null && widget.title!.isNotEmpty)
                                Positioned(
                                  top: 32,
                                  left: 44,
                                  right: 44,
                                  child: IgnorePointer(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title!,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D253F),
                                          ),
                                        ),
                                        const Divider(color: Color(0xFFE2E8F0), thickness: 1.5, height: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_currentEraserPos != null)
                                CustomPaint(
                                  painter: EraserCursorPainter(
                                    position: _currentEraserPos!,
                                    radius: _eraserRadius,
                                  ),
                                  size: const Size(860, 1220),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // VIRTUAL INTERACTIVE RULER OVERLAY
          if (_showRuler) _buildRulerOverlay(),

          // FREI VERSCHIEBBARE WERKZEUGLEISTE (Draggable Tool Dock mit KI-Agenten, Checkboxen, etc.)
          DraggableToolDock(
            keyboardEnabled: false,
            onToggleKeyboard: _toggleKeyboard,
            onOpenStylus: _openStylus,
            onOpenMathAI: _openMathAI,
            onOpenAudio: _openAudioRecorder,
            onInsertImage: _pickImage,
            onInsertChecklist: _insertChecklist,
            onExportTasks: _openChecklistToTasks,
            onTranscribeHandwriting: _transcribeHandwriting,
            onExportPdf: _exportPdf,
            onSearch: _searchInNote,
            onOpenAI: _showAIMenu,
          ),
        ],
      ),
    );
  }

  Widget _penStyleButton(PenStyle style, IconData icon, String tooltip) {
    final isSelected = _selectedStyle == style && !_isEraser && !_isPanMode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() {
          _selectedStyle = style;
          _isEraser = false;
          _isPanMode = false;
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD0E4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                tooltip,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRulerOverlay() {
    final deg = ((_rulerAngle * 180 / pi) % 360).round();

    return Positioned(
      left: _rulerPos.dx - (_rulerMode == 'circle' ? _circleRadius : _rulerLength / 2),
      top: _rulerPos.dy - (_rulerMode == 'circle' ? _circleRadius : 35),
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD).withAlpha(235),
            borderRadius: BorderRadius.circular(_rulerMode == 'circle' ? 999 : 14),
            border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ruler Top Control Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Move Handle
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() => _rulerPos += details.delta);
                      },
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: Row(
                          children: [
                            Icon(Icons.drag_indicator, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Lineal', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Angles: 0°, 45°, 90°
                    if (_rulerMode != 'circle') ...[
                      _anglePill('0°', 0.0),
                      _anglePill('45°', pi / 4),
                      _anglePill('90°', pi / 2),
                    ],

                    const SizedBox(width: 6),
                    // Angle display
                    Text('$deg°', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 8),

                    // Type Selector (Straight, Geodreieck, Circle)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                      tooltip: 'Lineal-Typ wählen',
                      onSelected: (mode) => setState(() => _rulerMode = mode),
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'straight', child: Text('Gerades Lineal (30 cm)')),
                        PopupMenuItem(value: 'triangle', child: Text('Geodreieck (Winkel)')),
                        PopupMenuItem(value: 'circle', child: Text('Kreis-Zirkel Schablone')),
                      ],
                    ),

                    // Close Ruler
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => setState(() => _showRuler = false),
                    ),
                  ],
                ),
              ),

              // Ruler Body with ticks and numbers
              if (_rulerMode == 'circle')
                Container(
                  width: _circleRadius * 2,
                  height: _circleRadius * 2,
                  alignment: Alignment.center,
                  child: Text(
                    'Ø ${( _circleRadius * 2 / 10).toStringAsFixed(1)} cm\n(Am Kreisrand zeichnen)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                  ),
                )
              else
                Container(
                  width: _rulerLength,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CustomPaint(
                    painter: RulerTicksPainter(length: _rulerLength),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _anglePill(String label, double rad) {
    final isActive = (_rulerAngle - rad).abs() < 0.05;
    return InkWell(
      onTap: () => setState(() => _rulerAngle = rad),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF1565C0) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class RulerTicksPainter extends CustomPainter {
  final double length;

  RulerTicksPainter({required this.length});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 1.0;

    const cmInterval = 30.0;
    const mmInterval = cmInterval / 10;
    int cmCount = 0;

    for (double x = 0; x <= length - 24; x += mmInterval) {
      final isCm = (x % cmInterval).abs() < 0.1;
      final isHalfCm = (x % (cmInterval / 2)).abs() < 0.1;

      final tickHeight = isCm ? 18.0 : (isHalfCm ? 12.0 : 6.0);
      canvas.drawLine(Offset(x, 0), Offset(x, tickHeight), tickPaint);

      if (isCm && cmCount > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$cmCount',
            style: const TextStyle(color: Color(0xFF1565C0), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tickHeight + 2));
      }
      if (isCm) cmCount++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StylusCanvasPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  StylusCanvasPainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, ?currentStroke]) {
      if (stroke.points.length < 2) continue;

      if (stroke.penStyle == PenStyle.dotted) {
        _paintDotted(canvas, stroke);
      } else if (stroke.penStyle == PenStyle.dashed) {
        _paintDashed(canvas, stroke);
      } else {
        _paintContinuous(canvas, stroke);
      }
    }
  }

  void _paintContinuous(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.penStyle == PenStyle.pencil
          ? stroke.color.withAlpha(190)
          : (stroke.penStyle == PenStyle.highlighter ? stroke.color.withAlpha(85) : stroke.color)
      ..strokeCap = stroke.penStyle == PenStyle.highlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(stroke.points.first.offset.dx, stroke.points.first.offset.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      final p0 = stroke.points[i - 1].offset;
      final p1 = stroke.points[i].offset;
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    // Calligraphy / Fountain pen dynamic pressure modulation
    if (stroke.penStyle == PenStyle.fountain) {
      paint.strokeWidth = stroke.width * (0.6 + stroke.points.last.pressure * 0.9);
    } else if (stroke.penStyle == PenStyle.brush) {
      paint.strokeWidth = stroke.width * (0.5 + stroke.points.last.pressure * 1.5);
    } else {
      paint.strokeWidth = stroke.width;
    }

    canvas.drawPath(path, paint);
  }

  void _paintDashed(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < stroke.points.length; i += 2) {
      final p0 = stroke.points[i - 1].offset;
      final p1 = stroke.points[i].offset;
      canvas.drawLine(p0, p1, paint);
    }
  }

  void _paintDotted(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < stroke.points.length; i += 3) {
      final p = stroke.points[i].offset;
      canvas.drawCircle(p, stroke.width / 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StylusCanvasPainter oldDelegate) => true;
}

class EraserCursorPainter extends CustomPainter {
  final Offset position;
  final double radius;

  EraserCursorPainter({required this.position, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0x331565C0)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(position, radius, fillPaint);
    canvas.drawCircle(position, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant EraserCursorPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.radius != radius;
}
