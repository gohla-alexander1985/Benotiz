import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate BEnotiz App Icons with big BE and cursive notiz', () async {
    const size512 = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size512, size512));

    // Background Gradient: Deep Navy to Royal Material Blue
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(size512, size512),
        [
          const Color(0xFF1565C0), // Royal Blue
          const Color(0xFF0B132B), // Deep Midnight Navy
        ],
      );

    // Rounded rectangle for icon
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, size512, size512),
      const Radius.circular(100),
    );
    canvas.drawRRect(rrect, bgPaint);

    // Subtle inner glowing border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(size512, size512),
        [
          const Color(0xFF64B5F6).withAlpha(180),
          const Color(0xFF1E88E5).withAlpha(60),
        ],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, size512 - 6, size512 - 6),
        const Radius.circular(97),
      ),
      borderPaint,
    );

    // Accent stylus line or subtle flourish
    final glowPaint = Paint()
      ..color = const Color(0xFF42A5F5).withAlpha(35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(const Offset(size512 / 2, size512 / 2 - 20), 160, glowPaint);

    // 1) Big Bold "BE"
    final beSpan = TextSpan(
      text: 'BE',
      style: const TextStyle(
        fontSize: 220,
        fontWeight: FontWeight.w900,
        letterSpacing: -6,
        color: Colors.white,
        shadows: [
          Shadow(
            color: Color(0x70000000),
            offset: Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
    );
    final bePainter = TextPainter(
      text: beSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    bePainter.layout();
    bePainter.paint(
      canvas,
      Offset((size512 - bePainter.width) / 2, 60),
    );

    // 2) Cursive / Handwritten "notiz" underneath
    final notizSpan = TextSpan(
      text: 'notiz',
      style: TextStyle(
        fontSize: 105,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontFamily: 'cursive',
        letterSpacing: 2,
        color: const Color(0xFF90CAF9),
        shadows: [
          Shadow(
            color: const Color(0xFF64B5F6).withAlpha(120),
            offset: const Offset(0, 0),
            blurRadius: 14,
          ),
          const Shadow(
            color: Color(0x80000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
    );
    final notizPainter = TextPainter(
      text: notizSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    notizPainter.layout();
    notizPainter.paint(
      canvas,
      Offset((size512 - notizPainter.width) / 2, 290),
    );

    // Little pen flourish underline under "notiz"
    final flourishPath = Path();
    flourishPath.moveTo(size512 / 2 - 110, 415);
    flourishPath.quadraticBezierTo(size512 / 2, 435, size512 / 2 + 110, 415);
    final flourishPaint = Paint()
      ..color = const Color(0xFF64B5F6).withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(flourishPath, flourishPaint);

    final picture = recorder.endRecording();
    final image512 = await picture.toImage(512, 512);
    final byteData512 = await image512.toByteData(format: ui.ImageByteFormat.png);
    final bytes512 = byteData512!.buffer.asUint8List();

    // Generate 192x192
    final recorder192 = ui.PictureRecorder();
    final canvas192 = Canvas(recorder192, const Rect.fromLTWH(0, 0, 192, 192));
    canvas192.scale(192.0 / 512.0);
    canvas192.drawPicture(picture);
    final image192 = await recorder192.endRecording().toImage(192, 192);
    final byteData192 = await image192.toByteData(format: ui.ImageByteFormat.png);
    final bytes192 = byteData192!.buffer.asUint8List();

    // Generate 64x64 favicon
    final recorder64 = ui.PictureRecorder();
    final canvas64 = Canvas(recorder64, const Rect.fromLTWH(0, 0, 64, 64));
    canvas64.scale(64.0 / 512.0);
    canvas64.drawPicture(picture);
    final image64 = await recorder64.endRecording().toImage(64, 64);
    final byteData64 = await image64.toByteData(format: ui.ImageByteFormat.png);
    final bytes64 = byteData64!.buffer.asUint8List();

    // Write to web icons
    File('web/icons/Icon-512.png').writeAsBytesSync(bytes512);
    File('web/icons/Icon-maskable-512.png').writeAsBytesSync(bytes512);
    File('web/icons/Icon-192.png').writeAsBytesSync(bytes192);
    File('web/icons/Icon-maskable-192.png').writeAsBytesSync(bytes192);
    File('web/favicon.png').writeAsBytesSync(bytes64);

    expect(File('web/icons/Icon-512.png').existsSync(), isTrue);
    expect(File('web/icons/Icon-192.png').existsSync(), isTrue);
    expect(File('web/favicon.png').existsSync(), isTrue);
  });
}
