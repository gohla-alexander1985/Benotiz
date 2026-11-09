import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/main.dart';
import 'package:notes_app/models/note.dart';
import 'package:notes_app/models/task_item.dart';
import 'package:notes_app/services/ai_service.dart';
import 'package:notes_app/services/math_engine.dart';
import 'package:notes_app/services/storage_service.dart';
import 'package:notes_app/services/task_service.dart';
import 'package:notes_app/services/text_analysis_engine.dart';
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

  group('MathEngine & TextAnalysisEngine tests', () {
    test('MathEngine correctly solves basic arithmetic', () {
      final res = MathEngine.instance.solve('(45 + 15) * 8 / 2');
      expect(res, contains('240'));
    });

    test('MathEngine correctly solves percentage calculations', () {
      final p1 = MathEngine.instance.solve('15% von 200');
      expect(p1, contains('30'));

      final p2 = MathEngine.instance.solve('200 + 19% MwSt');
      expect(p2, contains('238'));

      final p3 = MathEngine.instance.solve('500 - 20% Rabatt');
      expect(p3, contains('400'));
    });

    test('MathEngine solves linear equations', () {
      final res = MathEngine.instance.solve('2x + 6 = 18');
      expect(res, contains('x = 6'));
    });

    test('MathEngine solves geometry and formula problems', () {
      final kreis = MathEngine.instance.solve('Kreis r=5');
      expect(kreis, contains('78,54'));

      final pyth = MathEngine.instance.solve('Pythagoras 3, 4');
      expect(pyth, contains('5'));

      final binom = MathEngine.instance.completeFormula('(a+b)^2');
      expect(binom, contains('a² + 2ab + b²'));
    });

    test('TextAnalysisEngine extracts summary, keywords, and action items', () {
      const text = '''
Besprechung mit Benker GmbH & Co. KG in Dietenhofen.
Wir müssen die neuen Werkzeuge dringend bis Freitag prüfen und freigeben.
Die Qualität der Tiefziehteile ist hervorragend.
Bitte Herrn Schmidt anrufen und das Protokoll versenden.
''';

      final analysis = TextAnalysisEngine.instance.analyze(text);
      expect(analysis, contains('Kernaussagen'));
      expect(analysis, contains('Schlagwörter'));
      expect(analysis, contains('Handlungsfelder'));
      expect(analysis, contains('Kennzahlen'));
    });

    test('AIService integrates MathEngine and TextAnalysisEngine offline', () async {
      final mathRes = await AIService.instance.solveMathProblem(query: '3x + 12 = 48');
      expect(mathRes, contains('x = 12'));

      final summaryRes = await AIService.instance.summarizeText(
        'Projektmeeting zur Produktionslinie. Wir müssen die Maschinen morgen warten.',
      );
      expect(summaryRes, contains('Kernaussagen'));
    });

    test('TaskItem serialization with comments and completedBy', () {
      final comment = TaskComment.create(author: 'Kollege', text: 'Ist erledigt');
      final task = TaskItem.create(
        title: 'Musterteil prüfen',
        creatorName: 'Alexander',
      ).copyWith(
        isCompleted: true,
        completedBy: 'Kollege',
        comments: [comment],
      );

      final map = task.toMap();
      final restored = TaskItem.fromMap(map);

      expect(restored.title, 'Musterteil prüfen');
      expect(restored.creatorName, 'Alexander');
      expect(restored.isCompleted, isTrue);
      expect(restored.completedBy, 'Kollege');
      expect(restored.comments.length, 1);
      expect(restored.comments.first.author, 'Kollege');
      expect(restored.comments.first.text, 'Ist erledigt');
    });

    test('TaskService encode and decode share link with payload', () {
      final task = TaskItem.create(
        title: 'Werkzeugwechsel vorbereiten',
        description: 'Bitte bis 14 Uhr erledigen',
        creatorName: 'Alexander',
      );

      final link = TaskService.instance.generateTaskShareLink(task);
      expect(link, contains('import_task='));

      final uri = Uri.parse(link);
      final payload = uri.queryParameters['import_task']!;
      final decoded = TaskService.instance.decodeTaskFromPayload(payload);

      expect(decoded, isNotNull);
      expect(decoded!.title, 'Werkzeugwechsel vorbereiten');
      expect(decoded.description, 'Bitte bis 14 Uhr erledigen');
      expect(decoded.creatorName, 'Alexander');
    });

    test('TaskService deleteTaskWithUndo and undoLastDelete', () async {
      final task = TaskItem.create(title: 'Sicherheitsprüfung');
      await TaskService.instance.saveOrUpdateTask(task);

      final deleted = await TaskService.instance.deleteTaskWithUndo(task.id);
      expect(deleted?.title, 'Sicherheitsprüfung');

      final tasksAfterDelete = await TaskService.instance.loadTasks();
      expect(tasksAfterDelete.any((t) => t.id == task.id), isFalse);

      final restored = await TaskService.instance.undoLastDelete();
      expect(restored?.title, 'Sicherheitsprüfung');

      final tasksAfterUndo = await TaskService.instance.loadTasks();
      expect(tasksAfterUndo.any((t) => t.id == task.id), isTrue);
    });

    test('TaskService toggleTaskCompleted and undoLastStatusChange', () async {
      final task = TaskItem.create(title: 'Wartung durchführen');
      await TaskService.instance.saveOrUpdateTask(task);

      await TaskService.instance.toggleTaskCompleted(task.id, byUser: 'Tester');
      var loaded = (await TaskService.instance.loadTasks()).firstWhere((t) => t.id == task.id);
      expect(loaded.isCompleted, isTrue);
      expect(loaded.completedBy, 'Tester');

      await TaskService.instance.undoLastStatusChange();
      loaded = (await TaskService.instance.loadTasks()).firstWhere((t) => t.id == task.id);
      expect(loaded.isCompleted, isFalse);
      expect(loaded.completedBy, isNull);
    });
  });
}
