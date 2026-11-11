import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/widgets/stylus_canvas_screen.dart';

void main() {
  testWidgets('StylusCanvasScreen: stylus drag DOES NOT move the page, exclusively fingers pan & zoom', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    String? savedStrokes;

    await tester.pumpWidget(MaterialApp(
      home: StylusCanvasScreen(
        paperType: 'blank',
        onSave: (strokes, img) {
          savedStrokes = strokes;
        },
      ),
    ));
    await tester.pumpAndSettle();

    final ivFinder = find.byType(InteractiveViewer);
    expect(ivFinder, findsOneWidget);
    final iv = tester.widget<InteractiveViewer>(ivFinder);
    final controller = iv.transformationController!;

    final initialTranslation = controller.value.getTranslation();
    expect(initialTranslation.x, 0.0);
    expect(initialTranslation.y, 0.0);

    final canvasFinder = find.byKey(const Key('stylus_drawing_canvas'));
    final center = tester.getCenter(canvasFinder);

    // 1. Drag with STYLUS (Lenovo Pen) - page MUST NOT move!
    final stylusGesture = await tester.startGesture(center, kind: PointerDeviceKind.stylus);
    await stylusGesture.moveBy(const Offset(120, 120));
    await stylusGesture.up();
    await tester.pump();

    final translationAfterStylus = controller.value.getTranslation();
    // Translation must remain 0.0, 0.0! Page MUST NOT move with stylus!
    expect(translationAfterStylus.x, 0.0, reason: 'Stylus must not pan X');
    expect(translationAfterStylus.y, 0.0, reason: 'Stylus must not pan Y');

    // 2. Drag with FINGER (Touch) - page MUST move!
    final fingerGesture = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await fingerGesture.moveBy(const Offset(100, 80));
    await fingerGesture.up();
    await tester.pump();

    final translationAfterFinger = controller.value.getTranslation();
    // Translation MUST have changed!
    expect(translationAfterFinger.x, isNot(equals(0.0)), reason: 'Finger must pan X');
    expect(translationAfterFinger.y, isNot(equals(0.0)), reason: 'Finger must pan Y');

    // 3. Save and verify stylus stroke was recorded
    await tester.tap(find.text('Speichern'));
    await tester.pump();
    await tester.runAsync(() async => await Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(savedStrokes, isNotNull);
  });
}
