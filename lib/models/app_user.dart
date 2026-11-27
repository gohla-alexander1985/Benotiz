import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String position; // e.g. "Bauleiter", "Architekt", "Projektleiter", "Geschäftsführer"
  final List<String> groups; // e.g. ["Projekt Team", "Management"]
  final int colorValue; // Avatar background color
  final String passwordHash;
  final String salt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.position = '',
    this.groups = const [],
    this.colorValue = 0xFF1565C0,
    this.passwordHash = '',
    this.salt = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.create({
    required String firstName,
    required String lastName,
    required String email,
    String position = '',
    List<String> groups = const [],
    int? colorValue,
    String password = '',
  }) {
    final now = DateTime.now();
    final salt = password.isNotEmpty ? const Uuid().v4() : '';
    final hash = password.isNotEmpty ? hashPassword(password, salt) : '';

    return AppUser(
      id: const Uuid().v4(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim().toLowerCase(),
      position: position.trim(),
      groups: groups.map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
      colorValue: colorValue ?? _generateColorFor(firstName + lastName + email),
      passwordHash: hash,
      salt: salt,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AppUser.register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String position = '',
    List<String> groups = const [],
    int? colorValue,
  }) {
    return AppUser.create(
      firstName: firstName,
      lastName: lastName,
      email: email,
      position: position,
      groups: groups,
      colorValue: colorValue,
      password: password,
    );
  }

  static String hashPassword(String password, String salt) {
    if (password.isEmpty) return '';
    final bytes = utf8.encode('$salt:$password:benotiz_vault_v1');
    return sha256.convert(bytes).toString();
  }

  bool verifyPassword(String password) {
    if (passwordHash.isEmpty) return true; // Sample or legacy users without set password
    return hashPassword(password, salt) == passwordHash;
  }

  bool get hasPassword => passwordHash.isNotEmpty;

  static int _generateColorFor(String seed) {
    const colors = [
      0xFF1565C0, // Royal Blue
      0xFF2E7D32, // Emerald Green
      0xFF6A1B9A, // Purple
      0xFFC62828, // Red
      0xFFEF6C00, // Orange
      0xFF00838F, // Teal
      0xFF283593, // Indigo
      0xFF4E342E, // Brown
    ];
    if (seed.isEmpty) return colors.first;
    final hash = seed.codeUnits.fold(0, (acc, c) => acc + c);
    return colors[hash % colors.length];
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : email;
  }

  String get displayName {
    if (position.isNotEmpty) {
      return '$fullName ($position)';
    }
    return fullName;
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    if ((f + l).isNotEmpty) return '$f$l';
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  AppUser copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? position,
    List<String>? groups,
    int? colorValue,
    String? passwordHash,
    String? salt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      position: position ?? this.position,
      groups: groups ?? this.groups,
      colorValue: colorValue ?? this.colorValue,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'position': position,
    'groups': groups,
    'colorValue': colorValue,
    'passwordHash': passwordHash,
    'salt': salt,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String? ?? const Uuid().v4(),
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      position: map['position'] as String? ?? '',
      groups: (map['groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      colorValue: map['colorValue'] as int? ?? 0xFF1565C0,
      passwordHash: map['passwordHash'] as String? ?? '',
      salt: map['salt'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
