import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class HandwritingTaskPad extends StatefulWidget {
  final Function(String title, String description) onConverted;
  final VoidCallback? onCancel;

  const HandwritingTaskPad({
    super.key,
    required this.onConverted,
    this.onCancel,
  });

  @override
  State<HandwritingTaskPad> createState() => _HandwritingTaskPadState();
}

class _HandwritingTaskPadState extends State<HandwritingTaskPad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  bool _isConverting = false;

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _currentStroke = [event.localPosition];
      _strokes.add(_currentStroke!);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_currentStroke != null) {
      setState(() {
        _currentStroke!.add(event.localPosition);
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _currentStroke = null;
  }

  void _undoLastStroke() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  Future<void> _convertHandwritingToText() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✍️ Bitte schreibe zuerst mit dem Stift auf die Fläche.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isConverting = true);

    try {
      // 1. Render the strokes to an image
      final recorder = ui.PictureRecorder();
      const canvasWidth = 600.0;
      const canvasHeight = 240.0;
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

      // White background for OCR
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
        Paint()..color = Colors.white,
      );

      // Draw user strokes in dark ink
      final penPaint = Paint()
        ..color = const Color(0xFF0D253F)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (final stroke in _strokes) {
        if (stroke.length > 1) {
          final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
          for (int i = 1; i < stroke.length; i++) {
            path.lineTo(stroke[i].dx, stroke[i].dy);
          }
          canvas.drawPath(path, penPaint);
        } else if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, 2.0, Paint()..color = const Color(0xFF0D253F));
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final base64Image = base64Encode(pngBytes);

      // 2. Call OCR / handwriting transcription via AIService
      final recognizedText = await AIService.instance.transcribeHandwriting(base64Image);

      String title = '';
      String description = '';

      if (recognizedText.contains('OCR-Simulation') || recognizedText.isEmpty) {
        // Smart fallback dialog where user can confirm or dictate the printed text
        if (mounted) {
          final textCtrl = TextEditingController();
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.text_fields_rounded, color: Color(0xFF1565C0)),
                  SizedBox(width: 8),
                  Text('In Druckschrift umwandeln'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Handschrift erfolgreich erfasst! Prüfe oder ergänze die Druckschrift für die Aufgabe:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Aufgabe (Druckschrift)',
                      hintText: 'z.B.: Werkzeugträger freigeben und Max informieren',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Übernehmen'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );

          if (confirmed == true && textCtrl.text.trim().isNotEmpty) {
            final lines = textCtrl.text.trim().split('\n');
            title = lines.first.trim();
            if (lines.length > 1) {
              description = lines.sublist(1).join('\n').trim();
            }
          }
        }
      } else {
        // Clean recognized text
        final lines = recognizedText.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          title = lines.first.trim();
          if (lines.length > 1) {
            description = lines.sublist(1).join('\n').trim();
          }
        } else {
          title = recognizedText.trim();
        }
      }

      if (title.isNotEmpty) {
        widget.onConverted(title, description);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler bei der Handschrift-Erkennung: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D38) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E416B) : const Color(0xFF90CAF9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Instructions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162340) : const Color(0xFFE3F2FD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.draw_rounded, size: 18, color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✍️ Stift-Schreibfeld (Lenovo Pen / Stylus)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
                    ),
                  ),
                ),
                if (_strokes.isNotEmpty)
                  Text(
                    '${_strokes.length} Striche',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),

          // Writing Canvas Area (with lined paper guides)
          ClipRect(
            child: Container(
              height: 200,
              color: isDark ? const Color(0xFF0F1A33) : const Color(0xFFFAFDFF),
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: CustomPaint(
                  painter: _LinedCanvasPainter(
                    strokes: _strokes,
                    isDark: isDark,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          // Canvas Controls & Conversion Button
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      tooltip: 'Letzten Strich rückgängig machen',
                      onPressed: _strokes.isNotEmpty ? _undoLastStroke : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      tooltip: 'Schreibfläche leeren',
                      onPressed: _strokes.isNotEmpty ? _clearCanvas : null,
                    ),
                    const Spacer(),
                    if (widget.onCancel != null)
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text('Tastatur nutzen'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isConverting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    _isConverting ? 'Handschrift wird umgewandelt...' : 'In Druckschrift umwandeln',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isConverting ? null : _convertHandwritingToText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinedCanvasPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final bool isDark;

  _LinedCanvasPainter({required this.strokes, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle notebook guide lines
    final linePaint = Paint()
      ..color = isDark ? const Color(0xFF1E2D52) : const Color(0xFFD6E4F0)
      ..strokeWidth = 1.0;

    const lineSpacing = 36.0;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 2. Draw user strokes
    final strokePaint = Paint()
      ..color = isDark ? const Color(0xFFE2EDF8) : const Color(0xFF0D253F)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length > 1) {
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, strokePaint);
      } else if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.8, Paint()..color = strokePaint.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinedCanvasPainter oldDelegate) => true;
}
