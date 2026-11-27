import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';
import '../widgets/task_import_dialog.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'user_management_screen.dart';

class MainShell extends StatefulWidget {
  final bool? startAuthenticated;

  const MainShell({super.key, this.startAuthenticated});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _initAuthAndDeepLinks();
  }

  Future<void> _initAuthAndDeepLinks() async {
    // 1. Check deep links first (such as #sync= or ?user_login=)
    await _handleDeepLink();

    // 2. Determine authentication state
    bool isAuth = false;
    if (widget.startAuthenticated != null) {
      isAuth = widget.startAuthenticated!;
    } else {
      isAuth = await UserService.instance.isLoggedIn();
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _handleDeepLink() async {
    try {
      final uri = Uri.base;

      // 1. Multi-device full sync: ?sync=... or #sync=...
      String? syncPayload = uri.queryParameters['sync'];
      if (syncPayload == null || syncPayload.isEmpty) {
        final frag = uri.fragment;
        if (frag.contains('sync=')) {
          final idx = frag.indexOf('sync=');
          String sub = frag.substring(idx + 'sync='.length);
          if (sub.contains('&')) sub = sub.substring(0, sub.indexOf('&'));
          if (sub.contains('#')) sub = sub.substring(0, sub.indexOf('#'));
          syncPayload = sub;
        }
      }

      if (syncPayload != null && syncPayload.isNotEmpty) {
        final res = await SyncService.instance.importSyncBundle(syncPayload);
        if (res.success && mounted) {
          setState(() {
            _isAuthenticated = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Erfolgreich synchronisiert! ${res.user?.fullName ?? ''} angemeldet.'),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      // 2. Multi-device user login: ?user_login=... or #user_login=...
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
          await UserService.instance.saveUser(user);
          await UserService.instance.setCurrentUser(user);
          if (mounted) {
            setState(() {
              _isAuthenticated = true;
            });
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

      // 3. Task import link: ?import_task=... or #import_task=...
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

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return AuthScreen(
        onAuthenticated: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    final screens = [
      const HomeScreen(),
      const TasksScreen(),
      UserManagementScreen(
        onLogout: () {
          setState(() {
            _isAuthenticated = false;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
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
