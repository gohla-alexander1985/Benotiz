import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InteractiveViewer pan vs stylus test', (tester) async {
    final controller = TransformationController();
    final List<Offset> points = [];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: InteractiveViewer(
              transformationController: controller,
              minScale: 0.5,
              maxScale: 3.0,
              panEnabled: true,
              scaleEnabled: true,
              child: Container(
                width: 400,
                height: 400,
                color: Colors.white,
                child: Listener(
                  key: const Key('drawing_listener'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    if (e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.mouse) {
                      points.add(e.localPosition);
                    }
                  },
                  onPointerMove: (e) {
                    if (e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.mouse) {
                      points.add(e.localPosition);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    final center = tester.getCenter(find.byKey(const Key('drawing_listener')));
    
    // Drag with stylus: points recorded, NO translation
    final stylusGesture = await tester.startGesture(center, kind: PointerDeviceKind.stylus);
    await stylusGesture.moveBy(const Offset(50, 0));
    await stylusGesture.up();

    expect(points.length, greaterThanOrEqualTo(2));
    expect(controller.value.getTranslation().x, 0.0);
    expect(controller.value.getTranslation().y, 0.0);

    // Now touch with finger: points MUST NOT increase!
    final pointsCountBefore = points.length;
    final fingerGesture = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await fingerGesture.moveBy(const Offset(30, 20));
    await fingerGesture.up();

    expect(points.length, pointsCountBefore); // No new points from finger!
  });
}
