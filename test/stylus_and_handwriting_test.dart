import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/screens/note_edit_screen.dart';
import 'package:notes_app/widgets/be_notiz_logo.dart';
import 'package:notes_app/widgets/handwriting_task_pad.dart';
import 'package:notes_app/widgets/task_edit_dialog.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('de_DE', null);
  });

  testWidgets('BENotizLogo renders BE and cursive notiz', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: BENotizLogo(size: 64)),
      ),
    ));

    expect(find.text('BE'), findsOneWidget);
    expect(find.text('notiz'), findsOneWidget);
  });

  testWidgets('NoteEditScreen starts with keyboard disabled (stylus-first mode)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(
      home: NoteEditScreen(),
    ));
    await tester.pumpAndSettle();

    // Stylus-mode banner should be visible
    expect(find.text('✍️ Stift-Modus aktiv (Lenovo Pen)'), findsOneWidget);
    expect(find.text('Tastatur aktivieren'), findsOneWidget);

    // TextFields must be readOnly when keyboard is disabled
    final titleTextField = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText?.contains('Stift-Modus') == true),
    );
    expect(titleTextField.readOnly, isTrue);

    // Activating keyboard
    await tester.tap(find.text('Tastatur aktivieren'));
    await tester.pumpAndSettle();

    expect(find.text('⌨️ Tastatur aktiv (Tipp-Modus)'), findsOneWidget);
    expect(find.text('Stift-Modus'), findsOneWidget);

    final titleAfter = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Titel der Notiz...'),
    );
    expect(titleAfter.readOnly, isFalse);
  });

  testWidgets('TaskEditDialog defaults to stylus handwriting mode for new tasks', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TaskEditDialog(
          onSaved: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify segmented button and HandwritingTaskPad are shown
    expect(find.text('✍️ Stift (Handschrift)'), findsOneWidget);
    expect(find.text('⌨️ Tastatur / Text'), findsOneWidget);
    expect(find.byType(HandwritingTaskPad), findsOneWidget);
    expect(find.text('In Druckschrift umwandeln'), findsOneWidget);

    // Can toggle to keyboard mode
    await tester.tap(find.text('⌨️ Tastatur / Text'));
    await tester.pumpAndSettle();

    expect(find.byType(HandwritingTaskPad), findsNothing);
    expect(find.text('Aufgabentitel (Druckschrift) *'), findsOneWidget);
  });
}
