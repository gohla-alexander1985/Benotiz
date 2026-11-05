import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/main.dart';

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
}
