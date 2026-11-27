import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/models/app_user.dart';
import 'package:notes_app/models/note.dart';
import 'package:notes_app/models/task_item.dart';
import 'package:notes_app/services/user_service.dart';
import 'package:notes_app/services/task_service.dart';
import 'package:notes_app/services/storage_service.dart';
import 'package:notes_app/services/sync_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppUser Model & Password Security Tests', () {
    test('AppUser initializes with full name, initials and display properties', () {
      final user = AppUser.create(
        firstName: 'Alexander',
        lastName: 'Gohla',
        email: 'alexander@benotiz.de',
        position: 'Projektleiter',
        groups: ['Management', 'Entwicklung'],
        colorValue: 0xFF1565C0,
      );

      expect(user.fullName, 'Alexander Gohla');
      expect(user.displayName, 'Alexander Gohla (Projektleiter)');
      expect(user.initials, 'AG');
      expect(user.groups, contains('Management'));
      expect(user.groups, contains('Entwicklung'));
    });

    test('AppUser handles single name and empty position', () {
      final user = AppUser.create(
        firstName: 'Monika',
        lastName: '',
        email: 'monika@example.com',
      );

      expect(user.fullName, 'Monika');
      expect(user.displayName, 'Monika');
      expect(user.initials, 'M');
    });

    test('AppUser password registration and verification with salt + sha256', () {
      final user = AppUser.register(
        firstName: 'Alexander',
        lastName: 'Gohla',
        email: 'alex@firma.de',
        password: 'SuperSecretPassword123!',
        position: 'Geschäftsführer',
      );

      expect(user.hasPassword, true);
      expect(user.passwordHash.isNotEmpty, true);
      expect(user.salt.isNotEmpty, true);
      // Plain password is not stored anywhere
      expect(user.passwordHash != 'SuperSecretPassword123!', true);

      // Verification
      expect(user.verifyPassword('SuperSecretPassword123!'), true);
      expect(user.verifyPassword('WrongPassword'), false);
      expect(user.verifyPassword(''), false);
    });

    test('AppUser JSON serialization and deserialization roundtrip includes password fields', () {
      final user = AppUser.register(
        firstName: 'Sarah',
        lastName: 'Muster',
        email: 'sarah.muster@firma.de',
        password: 'PasswortSecure456',
        position: 'Buchhaltung',
        groups: ['Finanzen', 'Verwaltung'],
        colorValue: 0xFF2E7D32,
      );

      final map = user.toMap();
      final restored = AppUser.fromMap(map);

      expect(restored.id, user.id);
      expect(restored.firstName, 'Sarah');
      expect(restored.lastName, 'Muster');
      expect(restored.email, 'sarah.muster@firma.de');
      expect(restored.position, 'Buchhaltung');
      expect(restored.groups, equals(['Finanzen', 'Verwaltung']));
      expect(restored.colorValue, 0xFF2E7D32);
      expect(restored.passwordHash, user.passwordHash);
      expect(restored.salt, user.salt);
      expect(restored.verifyPassword('PasswortSecure456'), true);
    });
  });

  group('UserService Registration, Authentication & Session Tests', () {
    test('UserService initializes default users and groups when empty', () async {
      final service = UserService.instance;
      final users = await service.getUsers();
      final groups = await service.getAllGroups();

      expect(users.isNotEmpty, true);
      expect(groups.isNotEmpty, true);
      expect(groups, contains('Management'));
      expect(groups, contains('Projekt Team'));
    });

    test('UserService registerUser creates user and logs in', () async {
      final service = UserService.instance;
      final user = await service.registerUser(
        firstName: 'Max',
        lastName: 'Mustermann',
        email: 'max@beispiel.de',
        password: 'MeinSicheresPasswort!99',
        position: 'Projektleiter',
      );

      expect(user.fullName, 'Max Mustermann');
      expect(user.email, 'max@beispiel.de');
      expect(user.verifyPassword('MeinSicheresPasswort!99'), true);

      final isAuth = await service.isLoggedIn();
      expect(isAuth, true);

      final current = await service.getCurrentUser();
      expect(current.email, 'max@beispiel.de');
    });

    test('UserService loginWithCredentials verifies password and rejects wrong password', () async {
      final service = UserService.instance;
      await service.registerUser(
        firstName: 'Anna',
        lastName: 'Schmidt',
        email: 'anna@beispiel.de',
        password: 'GeheimesPasswort123',
        position: 'Architektin',
      );

      // Wrong password
      final wrongLogin = await service.loginWithCredentials(
        email: 'anna@beispiel.de',
        password: 'FalschesPasswort',
      );
      expect(wrongLogin, isNull);

      // Non-existent email
      final nonExistent = await service.loginWithCredentials(
        email: 'unbekannt@firma.de',
        password: 'GeheimesPasswort123',
      );
      expect(nonExistent, isNull);

      // Correct password
      final correctLogin = await service.loginWithCredentials(
        email: 'anna@beispiel.de',
        password: 'GeheimesPasswort123',
      );
      expect(correctLogin, isNotNull);
      expect(correctLogin?.fullName, 'Anna Schmidt');

      final current = await service.getCurrentUser();
      expect(current.email, 'anna@beispiel.de');
      expect(await service.isLoggedIn(), true);
    });

    test('UserService logout clears active session', () async {
      final service = UserService.instance;
      await service.registerUser(
        firstName: 'Tom',
        lastName: 'Test',
        email: 'tom@test.de',
        password: 'Password123!',
      );
      expect(await service.isLoggedIn(), true);

      await service.logout();
      expect(await service.isLoggedIn(), false);
    });

    test('UserService group management', () async {
      final service = UserService.instance;
      await service.addGroup('Sicherheit');
      var groups = await service.getAllGroups();
      expect(groups, contains('Sicherheit'));

      // Assign user to group
      final user = AppUser.create(
        firstName: 'Sec',
        lastName: 'Officer',
        email: 'sec@test.de',
        groups: ['Sicherheit'],
      );
      await service.saveUser(user);

      // Deleting group removes it from users
      await service.deleteGroup('Sicherheit');
      groups = await service.getAllGroups();
      expect(groups.contains('Sicherheit'), false);

      final refreshed = await service.getUserById(user.id);
      expect(refreshed?.groups.contains('Sicherheit'), false);
    });
  });

  group('SyncService Cross-Device Data Exchange Tests', () {
    test('SyncService exports data and imports on a secondary device', () async {
      final userService = UserService.instance;
      final storageService = StorageService.instance;
      final taskService = TaskService.instance;
      final syncService = SyncService.instance;

      // 1. Device A: User registers, creates a note and task
      final userA = await userService.registerUser(
        firstName: 'Alexander',
        lastName: 'Gohla',
        email: 'alexander@benotiz.de',
        password: 'MeinPasswort2026',
        position: 'Inhaber',
      );

      final now = DateTime.now();
      final noteA = Note(
        id: 'note-sync-1',
        title: 'Baustellenprotokoll #1',
        content: 'Alle Gewerke im Plan. Weiterführung morgen früh.',
        createdAt: now,
        updatedAt: now,
      );
      await storageService.saveOrUpdateNote(noteA);

      final taskA = TaskItem(
        id: 'task-sync-1',
        title: 'Gerüst freigeben',
        description: 'Prüfprotokoll unterschreiben',
        createdAt: now,
        updatedAt: now,
        assignedTo: 'Alexander Gohla',
      );
      await taskService.saveTasks([taskA]);

      // 2. Device A: Generate Sync Link
      final syncLink = await syncService.generateSyncLink();
      expect(syncLink, contains('#sync='));

      final uri = Uri.parse(syncLink);
      final payload = uri.fragment.replaceFirst('sync=', '');
      expect(payload.isNotEmpty, true);

      // 3. Device B: Simulate fresh second device
      SharedPreferences.setMockInitialValues({});
      expect(await userService.isLoggedIn(), false);

      // 4. Device B: Import sync bundle
      final syncResult = await syncService.importSyncBundle(payload);
      expect(syncResult.success, true);
      expect(syncResult.user?.email, userA.email);

      // 5. Verify Device B has user, notes, tasks and is authenticated
      expect(await userService.isLoggedIn(), true);
      final currentUserB = await userService.getCurrentUser();
      expect(currentUserB.fullName, 'Alexander Gohla');
      expect(currentUserB.verifyPassword('MeinPasswort2026'), true);

      final notesB = await storageService.loadNotes();
      expect(notesB.any((n) => n.id == 'note-sync-1'), true);

      final tasksB = await taskService.loadTasks();
      expect(tasksB.any((t) => t.id == 'task-sync-1'), true);
    });

    test('SyncService JSON export and import', () async {
      final syncService = SyncService.instance;
      final jsonStr = await syncService.exportDataJson();
      expect(jsonStr.contains('version'), true);
      expect(jsonStr.contains('notes'), true);
      expect(jsonStr.contains('tasks'), true);

      final result = await syncService.importSyncBundle(jsonStr);
      expect(result.success, true);
    });
  });

  group('TaskService Sharing & Attachment URL Safeguards', () {
    test('generateTaskShareLink trims large attachments to prevent 414 Request-URI Too Long', () {
      final largeBase64 = 'A' * 50000; // 50 KB base64 data
      final now = DateTime.now();
      final task = TaskItem(
        id: 'task-share-test',
        title: 'Große Aufgabe mit Anhang',
        description: 'Bitte bis Freitag erledigen',
        createdAt: now,
        updatedAt: now,
        attachments: [
          TaskAttachment(
            id: 'att-1',
            name: 'bericht.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 50000,
            base64Data: largeBase64,
          ),
        ],
      );

      final link = TaskService.instance.generateTaskShareLink(task);
      // Link should not contain the huge base64 payload
      expect(link.length < 3000, true);
      expect(link, contains('import_task='));

      // Decode back
      final uri = Uri.parse(link);
      final payload = uri.queryParameters['import_task']!;
      final restored = TaskService.instance.decodeTaskFromPayload(payload);
      expect(restored, isNotNull);
      expect(restored?.title, 'Große Aufgabe mit Anhang');
      expect(restored?.attachments.length, 1);
      expect(restored?.attachments.first.name, 'bericht.pdf');
      // Payload stripped raw base64 data to keep link lean and shareable
      expect(restored?.attachments.first.base64Data, isEmpty);
    });
  });
}
