import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/main.dart';
import 'package:notes_app/models/note.dart';
import 'package:notes_app/models/task_item.dart';
import 'package:notes_app/services/storage_service.dart';
import 'package:notes_app/services/task_service.dart';
import 'package:notes_app/widgets/stylus_canvas_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('de_DE', null);
  });

  testWidgets('App renders without crashing and shows BEnotiz branding',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BEnotizApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('BEnotiz'), findsWidgets);
    expect(find.text('Aufgaben'), findsOneWidget);
  });

  testWidgets('Selecting a template opens the note editor',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BEnotizApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on the FAB to open the template dialog
    final fabFinder = find.text('Neue A4 Notiz');
    expect(fabFinder, findsOneWidget);
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    // The template dialog should be visible with templates
    expect(find.text('DIN A4 Notizvorlage wählen'), findsOneWidget);
    expect(find.text('A4 Blanko'), findsOneWidget);

    // Tap on the 'A4 Blanko' template card
    await tester.tap(find.text('A4 Blanko'));
    await tester.pumpAndSettle();

    // Should now be inside NoteEditScreen with title and body fields
    expect(find.text('DIN A4 Notizvorlage wählen'), findsNothing);
    expect(find.text('Titel der Notiz...'), findsOneWidget);
  });

  testWidgets('StylusCanvasScreen eraser can be toggled and protects template lines',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      home: StylusCanvasScreen(
        paperType: 'grid',
        onSave: (strokes, img) {},
      ),
    ));
    await tester.pumpAndSettle();

    final eraserFinder = find.text('Radierer');
    expect(eraserFinder, findsOneWidget);
    expect(find.text('Vorlagenlinien geschützt'), findsNothing);

    // Ensure visible and tap on Radierer
    await tester.ensureVisible(eraserFinder);
    await tester.pumpAndSettle();
    await tester.tap(eraserFinder);
    await tester.pumpAndSettle();

    // Now eraser is active, protection badge should be visible
    expect(find.text('Vorlagenlinien geschützt'), findsOneWidget);
    final modeFinder = find.text('Ganze Striche');
    expect(modeFinder, findsOneWidget);

    // Toggle to precision mode
    await tester.ensureVisible(modeFinder);
    await tester.pumpAndSettle();
    await tester.tap(modeFinder);
    await tester.pumpAndSettle();
    expect(find.text('Präzision'), findsOneWidget);
  });

  testWidgets('Task shows originating note badge and links to original note',
      (WidgetTester tester) async {
    final note = Note(
      id: 'note_123',
      title: 'Projekt Benker Besprechung',
      content: 'Wichtige Details zum Tiefziehen',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await StorageService.instance.saveOrUpdateNote(note);

    final task = TaskItem.create(
      title: 'Werkzeugträger freigeben',
      linkedNoteId: note.id,
      linkedNoteTitle: note.title,
    );
    await TaskService.instance.saveOrUpdateTask(task);

    await tester.pumpWidget(const BEnotizApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Navigate to Aufgaben tab
    await tester.tap(find.text('Aufgaben'));
    await tester.pumpAndSettle();

    // Check task title is visible
    expect(find.text('Werkzeugträger freigeben'), findsOneWidget);

    // Originating note badge must be visible with note title
    final noteBadgeFinder = find.text('Notiz: Projekt Benker Besprechung');
    expect(noteBadgeFinder, findsOneWidget);

    // Tapping the note badge opens the note in editor
    await tester.tap(noteBadgeFinder);
    await tester.pumpAndSettle();

    // Now inside NoteEditScreen
    expect(find.text('Wichtige Details zum Tiefziehen'), findsOneWidget);
  });
}
