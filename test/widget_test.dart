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
}
