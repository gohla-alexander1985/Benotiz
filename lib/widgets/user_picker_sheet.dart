import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import 'user_edit_dialog.dart';

class SelectedAssignee {
  final AppUser? user;
  final String? group;

  const SelectedAssignee({this.user, this.group});

  bool get isUser => user != null;
  bool get isGroup => group != null;

  String get displayName => user?.fullName ?? group ?? '';
}

class UserPickerSheet extends StatefulWidget {
  final String? currentAssignedTo;
  final String? currentGroup;

  const UserPickerSheet({
    super.key,
    this.currentAssignedTo,
    this.currentGroup,
  });

  static Future<SelectedAssignee?> show(
    BuildContext context, {
    String? currentAssignedTo,
    String? currentGroup,
  }) {
    return showModalBottomSheet<SelectedAssignee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserPickerSheet(
        currentAssignedTo: currentAssignedTo,
        currentGroup: currentGroup,
      ),
    );
  }

  @override
  State<UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<UserPickerSheet> {
  List<AppUser> _users = [];
  List<String> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final users = await UserService.instance.getUsers();
    final groups = await UserService.instance.getAllGroups();
    setState(() {
      _users = users;
      _groups = groups;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.position.toLowerCase().contains(q) ||
          u.groups.any((g) => g.toLowerCase().contains(q));
    }).toList();
  }

  List<String> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    final q = _searchQuery.toLowerCase();
    return _groups.where((g) => g.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.people_alt_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Benutzer oder Gruppe auswählen',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Aufgabe zuweisen oder Notiz teilen',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Neu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final newUser = await showDialog<AppUser>(
                        context: context,
                        builder: (_) => const UserEditDialog(),
                      );
                      if (newUser != null && context.mounted) {
                        await _loadData();
                        if (context.mounted) {
                          Navigator.pop(context, SelectedAssignee(user: newUser));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Nach Name, Position, E-Mail oder Gruppe suchen...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        // Groups Section
                        if (_filteredGroups.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.folder_shared_outlined, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'GRUPPEN / TEAMS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _filteredGroups.map((group) {
                              final isSelected = widget.currentGroup == group;
                              final membersInGroup = _users.where((u) => u.groups.contains(group)).length;

                              return InkWell(
                                onTap: () => Navigator.pop(context, SelectedAssignee(group: group)),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.group_rounded,
                                        size: 16,
                                        color: isSelected ? Colors.white : theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        group,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withAlpha(50)
                                              : (isDark ? Colors.black26 : Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$membersInGroup',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                        ],

                        // Users Section
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'ANGELEGTE BENUTZER (${_filteredUsers.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_filteredUsers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Kein Benutzer für "$_searchQuery" gefunden.',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          )
                        else
                          ..._filteredUsers.map((user) {
                            final isSelected = widget.currentAssignedTo == user.fullName ||
                                widget.currentAssignedTo == user.email;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isSelected ? 2 : 0,
                              color: isSelected
                                  ? theme.colorScheme.primary.withAlpha(25)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                onTap: () => Navigator.pop(context, SelectedAssignee(user: user)),
                                leading: CircleAvatar(
                                  backgroundColor: Color(user.colorValue),
                                  foregroundColor: Colors.white,
                                  radius: 20,
                                  child: Text(
                                    user.initials,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 18),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (user.position.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withAlpha(20),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              user.position,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: Text(
                                            user.email,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (user.groups.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: user.groups.map((g) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.black26 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#$g',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
