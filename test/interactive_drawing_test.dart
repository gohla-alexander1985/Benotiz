import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/widgets/stylus_canvas_screen.dart';

void main() {
  testWidgets('StylusCanvasScreen: stylus drag DOES NOT move the page, palm touches do not move page, Verschieben tool and zoom work', (tester) async {
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
    expect(translationAfterStylus.x, 0.0, reason: 'Stylus must not pan X');
    expect(translationAfterStylus.y, 0.0, reason: 'Stylus must not pan Y');

    // 2. Palm/Finger touch while in writing mode - page MUST NOT move!
    final palmGesture = await tester.startGesture(center + const Offset(50, 50), kind: PointerDeviceKind.touch);
    await palmGesture.moveBy(const Offset(60, 40));
    await palmGesture.up();
    await tester.pump();

    final translationAfterPalm = controller.value.getTranslation();
    expect(translationAfterPalm.x, 0.0, reason: 'Resting palm/finger in writing mode must not pan X');
    expect(translationAfterPalm.y, 0.0, reason: 'Resting palm/finger in writing mode must not pan Y');

    // 3. Test Zoom buttons in AppBar
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('Hineinzoomen (+)'));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);

    await tester.tap(find.byTooltip('Herauszoomen (-)'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    // 4. Activate 'Verschieben' (Pan tool) and drag with finger -> page MUST move!
    final panToolFinder = find.text('Verschieben');
    expect(panToolFinder, findsOneWidget);
    await tester.tap(panToolFinder);
    await tester.pumpAndSettle();

    final fingerPanGesture = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await fingerPanGesture.moveBy(const Offset(100, 80));
    await fingerPanGesture.up();
    await tester.pump();

    final translationAfterPan = controller.value.getTranslation();
    expect(translationAfterPan.x, isNot(equals(0.0)), reason: 'In Verschieben mode, finger pans X');
    expect(translationAfterPan.y, isNot(equals(0.0)), reason: 'In Verschieben mode, finger pans Y');

    // 5. Select Kugelschreiber again -> Verschieben is disabled and writing mode is restored!
    await tester.tap(find.text('Kugelschreiber'));
    await tester.pumpAndSettle();

    // 6. Save and verify stylus stroke was recorded
    await tester.tap(find.text('Speichern'));
    await tester.pump();
    await tester.runAsync(() async => await Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(savedStrokes, isNotNull);
  });
}
