import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'a4_paper_sheet.dart';

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

class StylusCanvasScreen extends StatefulWidget {
  final String? initialDrawingData;
  final String paperType;
  final Function(String strokeDataJson, String imageBase64) onSave;

  const StylusCanvasScreen({
    super.key,
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

  Color _selectedColor = const Color(0xFF1565C0); // BEnotiz Blue
  double _strokeWidth = 3.5;
  PenStyle _selectedStyle = PenStyle.ballpoint;
  bool _isEraser = false;
  String _eraserMode = 'object'; // 'object' (Ganze Striche) oder 'precision' (Teil-Striche)
  double _eraserRadius = 24.0;
  Offset? _currentEraserPos;
  bool _stylusOnlyMode = false; // Palm rejection

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
    _loadInitialStrokes();
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
    if (_stylusOnlyMode &&
        event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
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

  Future<void> _saveAndExit() async {
    if (_strokes.isEmpty) {
      Navigator.pop(context);
      return;
    }

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
    final img = await picture.toImage(canvasSize.width.toInt(), canvasSize.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final base64Image = base64Encode(byteData.buffer.asUint8List());
      final strokeJson = json.encode(_strokes.map((s) => s.toMap()).toList());
      widget.onSave(strokeJson, base64Image);
    }

    if (mounted) Navigator.pop(context);
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.draw_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text(
              'Stifte & Lineale',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Palm Rejection Toggle Button
          IconButton(
            icon: Icon(
              Icons.do_not_touch_rounded,
              color: _stylusOnlyMode ? const Color(0xFF1565C0) : Colors.grey.shade600,
            ),
            tooltip: _stylusOnlyMode ? 'Nur Stift aktiv (Handballen ignoriert)' : 'Stift & Finger aktiv',
            onPressed: () => setState(() => _stylusOnlyMode = !_stylusOnlyMode),
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
                        onTap: () => setState(() => _isEraser = !_isEraser),
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

                      const SizedBox(width: 14),

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

              // Interactive Stylus Drawing Canvas with A4 background
              Expanded(
                child: Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: A4PaperPainter(paperType: widget.paperType),
                        foregroundPainter: StylusCanvasPainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                        ),
                        size: Size.infinite,
                      ),
                      if (_currentEraserPos != null)
                        CustomPaint(
                          painter: EraserCursorPainter(
                            position: _currentEraserPos!,
                            radius: _eraserRadius,
                          ),
                          size: Size.infinite,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // VIRTUAL INTERACTIVE RULER OVERLAY
          if (_showRuler) _buildRulerOverlay(),
        ],
      ),
    );
  }

  Widget _penStyleButton(PenStyle style, IconData icon, String tooltip) {
    final isSelected = _selectedStyle == style && !_isEraser;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() {
          _selectedStyle = style;
          _isEraser = false;
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
