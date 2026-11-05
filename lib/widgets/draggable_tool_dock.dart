import 'package:flutter/material.dart';

class DraggableToolDock extends StatefulWidget {
  final VoidCallback onOpenStylus;
  final VoidCallback onOpenMathAI;
  final VoidCallback onOpenAudio;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertChecklist;
  final VoidCallback onExportTasks;
  final VoidCallback onTranscribeHandwriting;
  final VoidCallback onExportPdf;
  final VoidCallback onSearch;
  final VoidCallback onOpenAI;

  const DraggableToolDock({
    super.key,
    required this.onOpenStylus,
    required this.onOpenMathAI,
    required this.onOpenAudio,
    required this.onInsertImage,
    required this.onInsertChecklist,
    required this.onExportTasks,
    required this.onTranscribeHandwriting,
    required this.onExportPdf,
    required this.onSearch,
    required this.onOpenAI,
  });

  @override
  State<DraggableToolDock> createState() => _DraggableToolDockState();
}

class _DraggableToolDockState extends State<DraggableToolDock> {
  Offset _position = const Offset(16, 75);
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx.clamp(8.0, (screenSize.width - (_isCollapsed ? 60 : 360)).clamp(8.0, double.infinity)),
      top: _position.dy.clamp(60.0, (screenSize.height - 80).clamp(60.0, double.infinity)),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D253F),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(40), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _position += details.delta;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      color: Color(0xFF90CAF9),
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Collapse / Expand Toggle
              IconButton(
                iconSize: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  color: Colors.white70,
                ),
                tooltip: _isCollapsed ? 'Werkzeuge ausklappen' : 'Einklappen',
                onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              ),

              if (!_isCollapsed) ...[
                const SizedBox(width: 4),
                _dockButton(
                  icon: Icons.draw_rounded,
                  color: const Color(0xFF42A5F5),
                  tooltip: 'Stift & Zeichnen (Tablet Stylus)',
                  onTap: widget.onOpenStylus,
                ),
                _dockButton(
                  icon: Icons.calculate_rounded,
                  color: const Color(0xFFFFB74D),
                  tooltip: 'Mathe-KI (Formeln lösen & Fragen stellen)',
                  onTap: widget.onOpenMathAI,
                ),
                _dockButton(
                  icon: Icons.mic_rounded,
                  color: const Color(0xFFEF5350),
                  tooltip: 'Tonaufnahme mit KI',
                  onTap: widget.onOpenAudio,
                ),
                _dockButton(
                  icon: Icons.checklist_rounded,
                  color: const Color(0xFF66BB6A),
                  tooltip: 'Checkliste einfügen',
                  onTap: widget.onInsertChecklist,
                ),
                _dockButton(
                  icon: Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF26A69A),
                  tooltip: 'Checklisten zu Aufgabenliste & Teilen',
                  onTap: widget.onExportTasks,
                ),
                _dockButton(
                  icon: Icons.text_fields_rounded,
                  color: const Color(0xFFAB47BC),
                  tooltip: 'Handschrift-zu-Text (OCR)',
                  onTap: widget.onTranscribeHandwriting,
                ),
                _dockButton(
                  icon: Icons.image_rounded,
                  color: const Color(0xFF29B6F6),
                  tooltip: 'Bild oder Kamera einfügen',
                  onTap: widget.onInsertImage,
                ),
                _dockButton(
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFFF7043),
                  tooltip: 'PDF Export / Drucken',
                  onTap: widget.onExportPdf,
                ),
                _dockButton(
                  icon: Icons.search_rounded,
                  color: const Color(0xFFB0BEC5),
                  tooltip: 'In Notiz suchen',
                  onTap: widget.onSearch,
                ),
                _dockButton(
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF90CAF9),
                  tooltip: 'KI-Assistent',
                  onTap: widget.onOpenAI,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dockButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }
}
