import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class UserService {
  static const String _usersKey = 'benotiz_users_v2';
  static const String _currentUserIdKey = 'benotiz_current_user_id_v2';
  static const String _customGroupsKey = 'antigravity_groups_v1';
  static const String appBaseUrl = 'https://gohla-alexander1985.github.io/Benotiz';

  static final UserService instance = UserService._internal();

  UserService._internal();

  AppUser? _cachedCurrentUser;

  /// Loads all configured users. Initializes defaults if empty.
  Future<List<AppUser>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_usersKey);

    if (jsonStr == null || jsonStr.trim().isEmpty) {
      final initialUsers = _createDefaultUsers();
      await saveUsersList(initialUsers);
      return initialUsers;
    }

    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      final users = decoded
          .map((m) => AppUser.fromMap(m as Map<String, dynamic>))
          .toList();
      if (users.isEmpty) {
        final initialUsers = _createDefaultUsers();
        await saveUsersList(initialUsers);
        return initialUsers;
      }
      return users;
    } catch (_) {
      final initialUsers = _createDefaultUsers();
      await saveUsersList(initialUsers);
      return initialUsers;
    }
  }

  Future<void> saveUsersList(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(users.map((u) => u.toMap()).toList());
    await prefs.setString(_usersKey, jsonStr);
  }

  /// Saves a new user or updates an existing one
  Future<void> saveUser(AppUser user) async {
    final users = await getUsers();
    final idx = users.indexWhere((u) => u.id == user.id || (u.email.isNotEmpty && u.email.toLowerCase() == user.email.toLowerCase()));

    if (idx >= 0) {
      users[idx] = user.copyWith(updatedAt: DateTime.now());
    } else {
      users.add(user);
    }

    await saveUsersList(users);

    // If updating current user, refresh cache
    if (_cachedCurrentUser?.id == user.id) {
      _cachedCurrentUser = user;
    }
  }

  /// Deletes a user by ID
  Future<void> deleteUser(String userId) async {
    final users = await getUsers();
    users.removeWhere((u) => u.id == userId);
    await saveUsersList(users);

    if (_cachedCurrentUser?.id == userId) {
      _cachedCurrentUser = users.isNotEmpty ? users.first : null;
      if (_cachedCurrentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserIdKey, _cachedCurrentUser!.id);
      }
    }
  }

  /// Gets current active user on this device
  Future<AppUser> getCurrentUser() async {
    if (_cachedCurrentUser != null) return _cachedCurrentUser!;

    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getString(_currentUserIdKey);
    final users = await getUsers();

    if (currentId != null) {
      final match = users.where((u) => u.id == currentId);
      if (match.isNotEmpty) {
        _cachedCurrentUser = match.first;
        return match.first;
      }
    }

    // Default to first user
    final primary = users.isNotEmpty ? users.first : _createDefaultUsers().first;
    _cachedCurrentUser = primary;
    await prefs.setString(_currentUserIdKey, primary.id);
    return primary;
  }

  /// Sets current active user (switches profile on this device)
  Future<void> setCurrentUser(AppUser user) async {
    _cachedCurrentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, user.id);
  }

  /// Logs in as user with the given email across devices.
  /// If user does not exist yet, creates a new profile.
  Future<AppUser> loginWithEmail(String email, {String? firstName, String? lastName, String? position}) async {
    final cleanEmail = email.trim().toLowerCase();
    final users = await getUsers();
    final match = users.where((u) => u.email.toLowerCase() == cleanEmail);

    AppUser user;
    if (match.isNotEmpty) {
      user = match.first;
    } else {
      user = AppUser.create(
        firstName: firstName ?? (cleanEmail.contains('@') ? cleanEmail.split('@').first : 'Benutzer'),
        lastName: lastName ?? '',
        email: cleanEmail,
        position: position ?? 'Mitarbeiter',
        groups: ['Projekt Team'],
      );
      await saveUser(user);
    }

    await setCurrentUser(user);
    return user;
  }

  /// Find user by email
  Future<AppUser?> getUserByEmail(String email) async {
    final clean = email.trim().toLowerCase();
    final users = await getUsers();
    final match = users.where((u) => u.email.toLowerCase() == clean);
    return match.isNotEmpty ? match.first : null;
  }

  /// Find user by ID
  Future<AppUser?> getUserById(String id) async {
    final users = await getUsers();
    final match = users.where((u) => u.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  /// Retrieves all groups from users and custom groups
  Future<List<String>> getAllGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customGroupsKey) ?? [];
    final users = await getUsers();

    final set = <String>{
      'Projekt Team',
      'Management',
      'Außendienst',
      'Planung',
      'Familie',
    };
    set.addAll(custom);
    for (final u in users) {
      set.addAll(u.groups);
    }

    final list = set.where((g) => g.trim().isNotEmpty).toList();
    list.sort();
    return list;
  }

  /// Adds a new group
  Future<void> addGroup(String groupName) async {
    final clean = groupName.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customGroupsKey) ?? [];
    if (!custom.contains(clean)) {
      custom.add(clean);
      await prefs.setStringList(_customGroupsKey, custom);
    }
  }

  /// Deletes a group
  Future<void> deleteGroup(String groupName) async {
    final clean = groupName.trim();
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customGroupsKey) ?? [];
    custom.remove(clean);
    await prefs.setStringList(_customGroupsKey, custom);

    // Remove group from all users
    final users = await getUsers();
    for (final user in users) {
      if (user.groups.contains(clean)) {
        final updatedGroups = List<String>.from(user.groups)..remove(clean);
        await saveUser(user.copyWith(groups: updatedGroups));
      }
    }
  }

  /// Generates a quick multi-device login link
  String generateDeviceLoginLink(AppUser user) {
    final payload = base64Url.encode(utf8.encode(json.encode(user.toMap())));
    return '$appBaseUrl/?user_login=$payload';
  }

  /// Decodes a user from login payload
  AppUser? decodeUserFromPayload(String payload) {
    try {
      final clean = payload.trim().replaceAll(' ', '+');
      final bytes = base64Url.decode(clean);
      final jsonStr = utf8.decode(bytes);
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return AppUser.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  List<AppUser> _createDefaultUsers() {
    final now = DateTime.now();
    return [
      AppUser(
        id: 'user_alexander_1',
        firstName: 'Alexander',
        lastName: 'Gohla',
        email: 'alexander@benotiz.local',
        position: 'Projektleiter / Inhaber',
        groups: ['Management', 'Projekt Team'],
        colorValue: 0xFF1565C0,
        createdAt: now,
        updatedAt: now,
      ),
      AppUser(
        id: 'user_sarah_2',
        firstName: 'Sarah',
        lastName: 'Weber',
        email: 'sarah.weber@benotiz.local',
        position: 'Bauleitung',
        groups: ['Projekt Team', 'Außendienst'],
        colorValue: 0xFF2E7D32,
        createdAt: now,
        updatedAt: now,
      ),
      AppUser(
        id: 'user_michael_3',
        firstName: 'Michael',
        lastName: 'Schmidt',
        email: 'michael.schmidt@benotiz.local',
        position: 'Architekt',
        groups: ['Planung', 'Projekt Team'],
        colorValue: 0xFF6A1B9A,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
