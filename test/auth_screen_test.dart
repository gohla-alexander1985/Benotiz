import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/screens/auth_screen.dart';
import 'package:notes_app/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AuthScreen shows BEnotiz branding, mode toggle and form fields', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool authenticated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () => authenticated = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BEnotiz'), findsOneWidget);
    expect(find.text('Konto erstellen'), findsWidgets);
    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('Vollständiger Name *'), findsOneWidget);
    expect(find.text('E-Mail-Adresse *'), findsOneWidget);
    expect(find.text('Passwort *'), findsOneWidget);
    expect(find.text('Passwort wiederholen *'), findsOneWidget);
    expect(find.text('Konto erstellen & App starten'), findsOneWidget);
  });

  testWidgets('AuthScreen validates required fields on registration', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool authenticated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () => authenticated = true),
      ),
    );
    await tester.pumpAndSettle();

    // Tap submit with empty fields
    await tester.ensureVisible(find.text('Konto erstellen & App starten'));
    await tester.tap(find.text('Konto erstellen & App starten'));
    await tester.pumpAndSettle();

    expect(find.text('Bitte gib deinen Namen ein.'), findsOneWidget);
    expect(find.text('Bitte gib deine E-Mail-Adresse ein.'), findsOneWidget);
    expect(find.text('Bitte gib ein Passwort ein.'), findsOneWidget);
    expect(authenticated, false);
  });

  testWidgets('AuthScreen registers user and calls onAuthenticated callback', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool authenticated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () => authenticated = true),
      ),
    );
    await tester.pumpAndSettle();

    // Enter valid details
    await tester.enterText(find.widgetWithText(TextFormField, 'Vollständiger Name *'), 'Alexander Gohla');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-Mail-Adresse *'), 'alexander@benotiz.de');
    await tester.enterText(find.widgetWithText(TextFormField, 'Passwort *'), 'SicheresPasswort123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Passwort wiederholen *'), 'SicheresPasswort123');
    await tester.pump();

    // Submit
    await tester.ensureVisible(find.text('Konto erstellen & App starten'));
    await tester.tap(find.text('Konto erstellen & App starten'));
    await tester.pumpAndSettle();

    expect(authenticated, true);
    expect(await UserService.instance.isLoggedIn(), true);
    final user = await UserService.instance.getCurrentUser();
    expect(user.email, 'alexander@benotiz.de');
  });

  testWidgets('AuthScreen switches to login mode and verifies credentials', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Pre-register user in service
    await UserService.instance.registerUser(
      firstName: 'Sarah',
      lastName: 'Weber',
      email: 'sarah@firma.de',
      password: 'Passwort456!',
    );
    await UserService.instance.logout();

    bool authenticated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () => authenticated = true),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Login tab
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();

    expect(find.text('Anmelden & Synchronisieren'), findsOneWidget);

    // Enter wrong password
    await tester.enterText(find.widgetWithText(TextFormField, 'E-Mail-Adresse *'), 'sarah@firma.de');
    await tester.enterText(find.widgetWithText(TextFormField, 'Passwort *'), 'FalschesPasswort');
    await tester.ensureVisible(find.text('Anmelden & Synchronisieren'));
    await tester.tap(find.text('Anmelden & Synchronisieren'));
    await tester.pumpAndSettle();

    expect(find.text('E-Mail oder Passwort ist falsch. Bitte überprüfe deine Eingaben.'), findsOneWidget);
    expect(authenticated, false);

    // Enter correct password
    await tester.enterText(find.widgetWithText(TextFormField, 'Passwort *'), 'Passwort456!');
    await tester.tap(find.text('Anmelden & Synchronisieren'));
    await tester.pumpAndSettle();

    expect(authenticated, true);
    expect(await UserService.instance.isLoggedIn(), true);
  });
}
