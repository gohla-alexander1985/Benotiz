import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class MathAIDialog extends StatefulWidget {
  final String? initialText;
  final String? drawingImageBase64;
  final ValueChanged<String> onInsertSolution;

  const MathAIDialog({
    super.key,
    this.initialText,
    this.drawingImageBase64,
    required this.onInsertSolution,
  });

  @override
  State<MathAIDialog> createState() => _MathAIDialogState();
}

class _MathAIDialogState extends State<MathAIDialog> {
  late TextEditingController _queryController;
  bool _isSolving = false;
  String? _solution;
  bool _useDrawingImage = true;

  static const List<String> _quickExamples = [
    '15% von 250',
    '250 + 19% MwSt',
    '3x + 12 = 48',
    '(a + b)²',
    'Kreis r=5',
    'Rechteck 12 x 8',
    'Pythagoras 3, 4',
    'U = R * I',
    'Zinsen für 5000 € bei 3.5% über 4 Jahre',
  ];

  @override
  void initState() {
    super.initState();
    String defaultText = '';
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      final raw = widget.initialText!.trim();
      final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length == 1 && lines.first.length <= 80) {
        defaultText = lines.first;
      } else {
        // Look for a line containing math symbols
        final mathRegex = RegExp(r'[=+\-*/^%√]|sqrt|kreis|rechteck|zinsen|dreisatz', caseSensitive: false);
        final mathLine = lines.firstWhere(
          (l) => mathRegex.hasMatch(l) && l.length <= 80,
          orElse: () => '',
        );
        defaultText = mathLine;
      }
    }
    _queryController = TextEditingController(text: defaultText);
    _useDrawingImage = widget.drawingImageBase64 != null;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _solveMath({bool enhanceOnly = false, String? directQuery}) async {
    final query = directQuery ?? _queryController.text.trim();
    if (query.isEmpty && (!_useDrawingImage || widget.drawingImageBase64 == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib eine Formel oder Frage ein, oder nutze eine Stift-Zeichnung.')),
      );
      return;
    }

    if (directQuery != null) {
      _queryController.text = directQuery;
    }

    setState(() => _isSolving = true);

    String result;
    if (enhanceOnly) {
      result = await AIService.instance.enhanceOrCompleteFormula(query);
    } else {
      result = await AIService.instance.solveMathProblem(
        query: query,
        drawingImageBase64: _useDrawingImage ? widget.drawingImageBase64 : null,
      );
    }

    setState(() {
      _solution = result;
      _isSolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDrawing = widget.drawingImageBase64 != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Color(0xFF1565C0), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mathe-KI & Formelrechner',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Formeln lösen, ergänzen oder mathematische Fragen stellen',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Handwritten formula toggle if drawing exists
                if (hasDrawing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0E4FF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.draw_rounded, size: 20, color: Color(0xFF1565C0)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Handschriftliche Stift-Formel einbeziehen',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: _useDrawingImage,
                          activeThumbColor: const Color(0xFF1565C0),
                          onChanged: (val) => setState(() => _useDrawingImage = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Input Field
                TextField(
                  controller: _queryController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Formel oder mathematische Fragestellung',
                    hintText: 'z.B.: "2x + 5 = 17" oder "15% von 250" oder "(a+b)^2"',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: _queryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                _queryController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Quick Presets
                Text(
                  'Schnellbeispiele zum Anklicken:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickExamples.map((ex) {
                    return ActionChip(
                      label: Text(ex, style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFFF0F4F8),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      onPressed: _isSolving ? null : () => _solveMath(directQuery: ex),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Lösen & Ausrechnen'),
                        onPressed: _isSolving ? null : () => _solveMath(enhanceOnly: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Ergänzen'),
                      onPressed: _isSolving ? null : () => _solveMath(enhanceOnly: true),
                    ),
                  ],
                ),

                if (_isSolving) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Berechne Lösung mit mathematischer KI...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],

                // Solution Display
                if (_solution != null && !_isSolving) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(
                    'Ergebnis & Rechenweg',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0E4FF)),
                    ),
                    child: SelectableText(
                      _solution!,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('In Notiz übernehmen'),
                        onPressed: () {
                          widget.onInsertSolution(_solution!);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Schließen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
