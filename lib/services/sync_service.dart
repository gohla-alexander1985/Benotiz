import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import 'storage_service.dart';
import 'task_service.dart';
import 'user_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final AppUser? user;
  final int notesCount;
  final int tasksCount;

  const SyncResult({
    required this.success,
    required this.message,
    this.user,
    this.notesCount = 0,
    this.tasksCount = 0,
  });
}

class SyncService {
  static final SyncService instance = SyncService._internal();

  SyncService._internal();

  static const String appBaseUrl = 'https://gohla-alexander1985.github.io/Benotiz';

  /// Generates a complete sync package containing user profile, notes, and tasks
  Future<Map<String, dynamic>> createSyncPackage() async {
    final user = await UserService.instance.getCurrentUser();
    final notes = await StorageService.instance.loadNotes();
    final tasks = await TaskService.instance.loadTasks();
    final groups = await UserService.instance.getAllGroups();

    return {
      'version': '1.0',
      'syncedAt': DateTime.now().toIso8601String(),
      'user': user.toMap(),
      'notes': notes.map((n) => n.toMap()).toList(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'groups': groups,
    };
  }

  /// Exports the sync package as a formatted JSON string (for file backup/exchange)
  Future<String> exportDataJson() async {
    final package = await createSyncPackage();
    return const JsonEncoder.withIndent('  ').convert(package);
  }

  /// Generates a compressed Base64Url sync bundle for link exchange
  Future<String> generateSyncPayload() async {
    final package = await createSyncPackage();

    // To ensure the sync link doesn't exceed URL limits, strip heavy raw base64 drawing/attachments from URL payload
    // If needed, the full data exchange is available via file export/import.
    final leanNotes = (package['notes'] as List<dynamic>).map((noteMap) {
      final copy = Map<String, dynamic>.from(noteMap as Map<String, dynamic>);
      return copy;
    }).toList();

    final leanTasks = (package['tasks'] as List<dynamic>).map((taskMap) {
      final copy = Map<String, dynamic>.from(taskMap as Map<String, dynamic>);
      if (copy['attachments'] is List) {
        copy['attachments'] = (copy['attachments'] as List).map((att) {
          final attCopy = Map<String, dynamic>.from(att as Map<String, dynamic>);
          attCopy['base64Data'] = ''; // strip raw binary for link transport
          return attCopy;
        }).toList();
      }
      return copy;
    }).toList();

    final leanPackage = {
      'version': '1.0',
      'syncedAt': package['syncedAt'],
      'user': package['user'],
      'notes': leanNotes,
      'tasks': leanTasks,
      'groups': package['groups'],
    };

    final jsonStr = json.encode(leanPackage);
    return base64Url.encode(utf8.encode(jsonStr));
  }

  /// Generates a live multi-device sync link with hash fragment
  Future<String> generateSyncLink() async {
    final payload = await generateSyncPayload();
    return '$appBaseUrl/#sync=$payload';
  }

  /// Imports and applies a sync payload or JSON package
  Future<SyncResult> importSyncBundle(String payloadOrJson) async {
    try {
      Map<String, dynamic> package;
      final clean = payloadOrJson.trim();

      if (clean.startsWith('{')) {
        // Direct JSON format
        package = json.decode(clean) as Map<String, dynamic>;
      } else {
        // Base64 or Base64Url format
        String normalized = clean.replaceAll(' ', '+');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        List<int> bytes;
        try {
          bytes = base64Url.decode(normalized);
        } catch (_) {
          bytes = base64.decode(normalized);
        }
        final jsonStr = utf8.decode(bytes);
        package = json.decode(jsonStr) as Map<String, dynamic>;
      }

      // 1. Restore User
      AppUser? syncedUser;
      if (package['user'] != null) {
        syncedUser = AppUser.fromMap(package['user'] as Map<String, dynamic>);
        await UserService.instance.saveUser(syncedUser);
        await UserService.instance.setCurrentUser(syncedUser);
      }

      // 2. Restore Groups
      if (package['groups'] is List) {
        for (final g in package['groups'] as List<dynamic>) {
          await UserService.instance.addGroup(g.toString());
        }
      }

      // 3. Merge Notes
      int importedNotesCount = 0;
      if (package['notes'] is List) {
        final existingNotes = await StorageService.instance.loadNotes();
        final existingMap = {for (final n in existingNotes) n.id: n};

        for (final item in package['notes'] as List<dynamic>) {
          try {
            final incomingNote = Note.fromMap(item as Map<String, dynamic>);
            if (existingMap.containsKey(incomingNote.id)) {
              // Compare updatedAt and keep the latest
              final local = existingMap[incomingNote.id]!;
              if (incomingNote.updatedAt.isAfter(local.updatedAt)) {
                existingMap[incomingNote.id] = incomingNote;
              }
            } else {
              existingMap[incomingNote.id] = incomingNote;
            }
            importedNotesCount++;
          } catch (e) {
            debugPrint('Note import item error: $e');
          }
        }
        await StorageService.instance.saveNotes(existingMap.values.toList());
      }

      // 4. Merge Tasks
      int importedTasksCount = 0;
      if (package['tasks'] is List) {
        final existingTasks = await TaskService.instance.loadTasks();
        final existingMap = {for (final t in existingTasks) t.id: t};

        for (final item in package['tasks'] as List<dynamic>) {
          try {
            final incomingTask = TaskItem.fromMap(item as Map<String, dynamic>);
            if (existingMap.containsKey(incomingTask.id)) {
              final local = existingMap[incomingTask.id]!;
              if (incomingTask.updatedAt.isAfter(local.updatedAt)) {
                existingMap[incomingTask.id] = incomingTask;
              }
            } else {
              existingMap[incomingTask.id] = incomingTask;
            }
            importedTasksCount++;
          } catch (e) {
            debugPrint('Task import item error: $e');
          }
        }
        await TaskService.instance.saveTasks(existingMap.values.toList());
      }

      await UserService.instance.setLoggedIn(true);

      return SyncResult(
        success: true,
        message: 'Synchronisation erfolgreich! ${syncedUser?.fullName ?? ''} angemeldet.',
        user: syncedUser,
        notesCount: importedNotesCount,
        tasksCount: importedTasksCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Fehler beim Einlesen der Synchronisationsdaten: $e',
      );
    }
  }
}
