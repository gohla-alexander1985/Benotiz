import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'ai_settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _handleDeepLink();
  }

  void _handleDeepLink() {
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('task') || uri.queryParameters.containsKey('tasks')) {
        _currentIndex = 1;
      }
    } catch (_) {}
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    TasksScreen(),
    AISettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: 'Notizen',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: 'Aufgaben',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'KI & Gruppen',
          ),
        ],
      ),
    );
  }
}
