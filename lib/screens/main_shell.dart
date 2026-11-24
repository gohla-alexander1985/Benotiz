import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';
import '../widgets/task_import_dialog.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'user_management_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeepLink();
    });
  }

  void _handleDeepLink() {
    try {
      final uri = Uri.base;

      // 1. Check for multi-device user login: ?user_login=... or #user_login=...
      String? userPayload = uri.queryParameters['user_login'];
      if (userPayload == null || userPayload.isEmpty) {
        final frag = uri.fragment;
        if (frag.contains('user_login=')) {
          final idx = frag.indexOf('user_login=');
          String sub = frag.substring(idx + 'user_login='.length);
          if (sub.contains('&')) sub = sub.substring(0, sub.indexOf('&'));
          if (sub.contains('#')) sub = sub.substring(0, sub.indexOf('#'));
          userPayload = sub;
        }
      }

      if (userPayload != null && userPayload.isNotEmpty) {
        final user = UserService.instance.decodeUserFromPayload(userPayload);
        if (user != null) {
          UserService.instance.saveUser(user);
          UserService.instance.setCurrentUser(user);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('👤 Angemeldet als ${user.fullName} (${user.position})!'),
                backgroundColor: const Color(0xFF1565C0),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      // 2. Check for task import link: ?import_task=... or #import_task=...
      String? payload = uri.queryParameters['import_task'];
      if (payload == null || payload.isEmpty) {
        final frag = uri.fragment;
        if (frag.contains('import_task=')) {
          final idx = frag.indexOf('import_task=');
          String sub = frag.substring(idx + 'import_task='.length);
          if (sub.contains('&')) sub = sub.substring(0, sub.indexOf('&'));
          if (sub.contains('#')) sub = sub.substring(0, sub.indexOf('#'));
          payload = sub;
        }
      }

      if (payload != null && payload.isNotEmpty) {
        final task = TaskService.instance.decodeTaskFromPayload(payload);
        if (task != null && mounted) {
          setState(() {
            _currentIndex = 1; // Switch to Aufgaben
          });
          showDialog(
            context: context,
            builder: (_) => TaskImportDialog(
              importedTask: task,
              onImported: () {
                setState(() {});
              },
            ),
          );
          return;
        }
      }

      if (uri.queryParameters.containsKey('task') ||
          uri.queryParameters.containsKey('tasks') ||
          uri.fragment.contains('task')) {
        setState(() {
          _currentIndex = 1;
        });
      }
    } catch (_) {}
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    TasksScreen(),
    UserManagementScreen(),
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
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'Team & Benutzer',
          ),
        ],
      ),
    );
  }
}
