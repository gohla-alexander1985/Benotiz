import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);
  runApp(const BEnotizApp());
}

class BEnotizApp extends StatelessWidget {
  const BEnotizApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Elegant, modern blue theme palette
    const primaryBlue = Color(0xFF1565C0); // Royal / Material Blue
    const lightBackground = Color(0xFFF3F7FC); // Subtle ice-blue white
    const darkBackground = Color(0xFF0B132B); // Deep midnight navy

    return MaterialApp(
      title: 'BEnotiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          surface: lightBackground,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: lightBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: lightBackground,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Color(0xFF0D253F),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: const Color(0xFFD0E4FF),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: primaryBlue);
            }
            return const IconThemeData(color: Color(0xFF4A6572));
          }),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42A5F5),
          primary: const Color(0xFF64B5F6),
          surface: darkBackground,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: darkBackground,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Color(0xFFE2EDF8),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF111D3B),
          indicatorColor: const Color(0xFF1D3557),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF90CAF9));
            }
            return const IconThemeData(color: Color(0xFF8FA3BF));
          }),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}
