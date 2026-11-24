import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/models/app_user.dart';
import 'package:notes_app/models/task_item.dart';
import 'package:notes_app/services/user_service.dart';
import 'package:notes_app/services/task_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppUser Model Tests', () {
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

    test('AppUser JSON serialization and deserialization roundtrip', () {
      final user = AppUser.create(
        firstName: 'Sarah',
        lastName: 'Muster',
        email: 'sarah.muster@firma.de',
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
    });
  });

  group('UserService CRUD & Multi-Device Sync Tests', () {
    test('UserService initializes default users and groups when empty', () async {
      final service = UserService.instance;
      final users = await service.getUsers();
      final groups = await service.getAllGroups();

      expect(users.isNotEmpty, true);
      expect(groups.isNotEmpty, true);
      expect(groups, contains('Management'));
      expect(groups, contains('Projekt Team'));
    });

    test('UserService adds, updates, and deletes users', () async {
      final service = UserService.instance;
      final newUser = AppUser.create(
        firstName: 'Test',
        lastName: 'Nutzer',
        email: 'test@nutzer.de',
        position: 'Tester',
        groups: ['QA'],
      );

      await service.saveUser(newUser);
      var users = await service.getUsers();
      expect(users.any((u) => u.id == newUser.id), true);

      // Update
      final updated = newUser.copyWith(position: 'Senior QA', groups: ['QA', 'Entwicklung']);
      await service.saveUser(updated);
      var fetched = await service.getUserById(newUser.id);
      expect(fetched?.position, 'Senior QA');
      expect(fetched?.groups, contains('Entwicklung'));

      // Delete
      await service.deleteUser(newUser.id);
      users = await service.getUsers();
      expect(users.any((u) => u.id == newUser.id), false);
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

    test('UserService active current user and device login link generation/decoding', () async {
      final service = UserService.instance;
      final users = await service.getUsers();
      final firstUser = users.first;

      await service.setCurrentUser(firstUser);
      final current = await service.getCurrentUser();
      expect(current?.id, firstUser.id);

      // Generate multi-device login link
      final link = service.generateDeviceLoginLink(firstUser);
      expect(link, contains('user_login='));

      // Extract payload
      final uri = Uri.parse(link);
      final payload = uri.queryParameters['user_login'] ?? uri.fragment.replaceFirst('user_login=', '');
      expect(payload.isNotEmpty, true);

      // Decode payload on another device
      final decodedUser = service.decodeUserFromPayload(payload);
      expect(decodedUser, isNotNull);
      expect(decodedUser?.email, firstUser.email);
      expect(decodedUser?.firstName, firstUser.firstName);
    });

    test('UserService loginWithEmail switches or creates active user', () async {
      final service = UserService.instance;
      final user = await service.loginWithEmail(
        'neuer.mitarbeiter@firma.de',
        firstName: 'Neuer',
        lastName: 'Kollege',
      );
      expect(user, isNotNull);
      expect(user.email, 'neuer.mitarbeiter@firma.de');
      expect(user.firstName, 'Neuer');

      final current = await service.getCurrentUser();
      expect(current?.email, 'neuer.mitarbeiter@firma.de');
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
