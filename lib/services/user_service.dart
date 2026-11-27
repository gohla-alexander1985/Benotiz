import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';

class UserService {
  static const String _usersKey = 'benotiz_users_v2';
  static const String _currentUserIdKey = 'benotiz_current_user_id_v2';
  static const String _isLoggedInKey = 'benotiz_is_logged_in_v2';
  static const String _customGroupsKey = 'antigravity_groups_v1';
  static const String appBaseUrl = 'https://gohla-alexander1985.github.io/Benotiz';

  static final UserService instance = UserService._internal();

  UserService._internal();

  AppUser? _cachedCurrentUser;

  /// Returns true if a user is currently logged in on this device
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_isLoggedInKey);
    if (loggedIn != null) return loggedIn;

    // Fallback: If not explicitly set, check if current user id is saved
    final currentId = prefs.getString(_currentUserIdKey);
    return currentId != null && currentId.isNotEmpty;
  }

  /// Sets the authentication status
  Future<void> setLoggedIn(bool loggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, loggedIn);
  }

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

  /// Registers a new user with full credentials (Name, E-Mail, Password)
  Future<AppUser> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String position = '',
    List<String> groups = const [],
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final users = await getUsers();
    final existingIdx = users.indexWhere((u) => u.email.toLowerCase() == cleanEmail);

    AppUser user;
    if (existingIdx >= 0) {
      // Update existing user with credentials
      final existing = users[existingIdx];
      final salt = const Uuid().v4();
      final hash = AppUser.hashPassword(password, salt);
      user = existing.copyWith(
        firstName: firstName.trim().isNotEmpty ? firstName.trim() : existing.firstName,
        lastName: lastName.trim().isNotEmpty ? lastName.trim() : existing.lastName,
        position: position.trim().isNotEmpty ? position.trim() : existing.position,
        groups: groups.isNotEmpty ? groups : existing.groups,
        passwordHash: hash,
        salt: salt,
        updatedAt: DateTime.now(),
      );
    } else {
      user = AppUser.register(
        firstName: firstName,
        lastName: lastName,
        email: cleanEmail,
        password: password,
        position: position,
        groups: groups.isNotEmpty ? groups : ['Projekt Team'],
      );
    }

    await saveUser(user);
    await setCurrentUser(user);
    await setLoggedIn(true);
    return user;
  }

  /// Logs in using Email and Password
  Future<AppUser?> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final user = await getUserByEmail(cleanEmail);
    if (user == null) return null;

    if (!user.verifyPassword(password)) {
      return null;
    }

    await setCurrentUser(user);
    await setLoggedIn(true);
    return user;
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
      } else {
        await logout();
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
    await prefs.setBool(_isLoggedInKey, true);
  }

  /// Logs out of the current device
  Future<void> logout() async {
    _cachedCurrentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_currentUserIdKey);
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
    await setLoggedIn(true);
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
    return [
      AppUser.create(
        firstName: 'Alexander',
        lastName: 'Gohla',
        email: 'alexander@benotiz.local',
        position: 'Projektleiter / Inhaber',
        groups: ['Management', 'Projekt Team'],
        colorValue: 0xFF1565C0,
        password: '', // Blank password allowed for defaults
      ),
      AppUser.create(
        firstName: 'Sarah',
        lastName: 'Weber',
        email: 'sarah.weber@benotiz.local',
        position: 'Bauleitung',
        groups: ['Projekt Team', 'Außendienst'],
        colorValue: 0xFF2E7D32,
      ),
      AppUser.create(
        firstName: 'Michael',
        lastName: 'Schmidt',
        email: 'michael.schmidt@benotiz.local',
        position: 'Architekt',
        groups: ['Planung', 'Projekt Team'],
        colorValue: 0xFF6A1B9A,
      ),
    ];
  }
}
