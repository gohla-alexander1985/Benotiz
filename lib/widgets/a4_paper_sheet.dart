import 'package:flutter/material.dart';

class A4PaperSheet extends StatelessWidget {
  final String paperType; // 'blank', 'grid', 'lined', 'dots', 'cornell', 'meeting', 'planner', 'custom'
  final String? backgroundImageBase64;
  final Widget child;

  const A4PaperSheet({
    super.key,
    required this.paperType,
    this.backgroundImageBase64,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 820, // Standard DIN A4 width on tablet / desktop screens
          minHeight: 820 * 1.4142, // DIN A4 Aspect Ratio 1 : √2 (1.4142)
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: A4PaperPainter(
              paperType: paperType,
              backgroundImageBase64: backgroundImageBase64,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: paperType == 'lined' ? 48.0 : (paperType == 'cornell' ? 24.0 : 32.0),
                right: 32.0,
                top: 36.0,
                bottom: paperType == 'cornell' ? 140.0 : 40.0,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class A4PaperPainter extends CustomPainter {
  final String paperType;
  final String? backgroundImageBase64;

  A4PaperPainter({
    required this.paperType,
    this.backgroundImageBase64,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (paperType == 'blank') return;

    if (paperType == 'grid' || paperType == 'planner') {
      _paintGrid(canvas, size);
    } else if (paperType == 'lined') {
      _paintLined(canvas, size);
    } else if (paperType == 'dots') {
      _paintDots(canvas, size);
    } else if (paperType == 'cornell') {
      _paintCornell(canvas, size);
    } else if (paperType == 'meeting') {
      _paintMeeting(canvas, size);
    }

    if (backgroundImageBase64 != null && backgroundImageBase64!.isNotEmpty) {
      // Background image watermark / template overlay
      // Note: rendered via image decoder or UI if needed
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD6E4F0) // Soft A4 Grid Blue
      ..strokeWidth = 0.8;

    const step = 20.0; // ~5mm scale
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintLined(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 0.8;

    final marginPaint = Paint()
      ..color = const Color(0xFFEF9A9A) // Classic Red Margin line
      ..strokeWidth = 1.2;

    const lineSpacing = 28.0;
    const startY = 60.0;

    for (double y = startY; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Vertical margin line at 42px
    canvas.drawLine(const Offset(42, 0), Offset(42, size.height), marginPaint);
  }

  void _paintDots(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF90A4AE).withAlpha(150)
      ..style = PaintingStyle.fill;

    const step = 22.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  void _paintCornell(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 0.8;

    final dividerPaint = Paint()
      ..color = const Color(0xFF1565C0).withAlpha(120)
      ..strokeWidth = 1.8;

    // Cornell layout: Vertical cue column at 200px
    const cueColumnWidth = 200.0;
    canvas.drawLine(
      const Offset(cueColumnWidth, 50),
      Offset(cueColumnWidth, size.height - 120),
      dividerPaint,
    );

    // Summary horizontal line at bottom 120px
    canvas.drawLine(
      Offset(0, size.height - 120),
      Offset(size.width, size.height - 120),
      dividerPaint,
    );

    // Horizontal ruled lines in right column
    const lineSpacing = 28.0;
    for (double y = 80.0; y < size.height - 120; y += lineSpacing) {
      canvas.drawLine(Offset(cueColumnWidth, y), Offset(size.width, y), linePaint);
    }
  }

  void _paintMeeting(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;

    const step = 24.0;
    for (double y = 80.0; y < size.height; y += step) {
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant A4PaperPainter oldDelegate) =>
      oldDelegate.paperType != paperType ||
      oldDelegate.backgroundImageBase64 != backgroundImageBase64;
}
