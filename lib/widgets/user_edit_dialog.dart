import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';

class UserEditDialog extends StatefulWidget {
  final AppUser? user; // If null, creating new user
  final ValueChanged<AppUser>? onSaved;

  const UserEditDialog({
    super.key,
    this.user,
    this.onSaved,
  });

  @override
  State<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _positionController;
  late List<String> _selectedGroups;
  late int _selectedColor;
  List<String> _availableGroups = [];
  bool _isLoadingGroups = true;

  final List<int> _avatarColors = const [
    0xFF1565C0, // Royal Blue
    0xFF2E7D32, // Emerald Green
    0xFF6A1B9A, // Purple
    0xFFC62828, // Red
    0xFFEF6C00, // Orange
    0xFF00838F, // Teal
    0xFF283593, // Indigo
    0xFF4E342E, // Brown
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _firstNameController = TextEditingController(text: u?.firstName ?? '');
    _lastNameController = TextEditingController(text: u?.lastName ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _positionController = TextEditingController(text: u?.position ?? '');
    _selectedGroups = List.from(u?.groups ?? ['Projekt Team']);
    _selectedColor = u?.colorValue ?? _avatarColors.first;

    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await UserService.instance.getAllGroups();
    setState(() {
      _availableGroups = groups;
      _isLoadingGroups = false;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final position = _positionController.text.trim();

    final user = (widget.user ?? AppUser.create(
      firstName: firstName,
      lastName: lastName,
      email: email,
      position: position,
      groups: _selectedGroups,
      colorValue: _selectedColor,
    )).copyWith(
      firstName: firstName,
      lastName: lastName,
      email: email,
      position: position,
      groups: _selectedGroups,
      colorValue: _selectedColor,
      updatedAt: DateTime.now(),
    );

    await UserService.instance.saveUser(user);
    widget.onSaved?.call(user);

    if (mounted) {
      Navigator.pop(context, user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Benutzer "${user.fullName}" erfolgreich gespeichert!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  void _addNewGroupPrompt() {
    final groupCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neue Gruppe erstellen'),
        content: TextField(
          controller: groupCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'z.B. Bauleitung, Produktion, Vertrieb',
            labelText: 'Gruppenname',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = groupCtrl.text.trim();
              if (name.isNotEmpty) {
                await UserService.instance.addGroup(name);
                await _loadGroups();
                if (!_selectedGroups.contains(name)) {
                  setState(() => _selectedGroups.add(name));
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.user != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(_selectedColor).withAlpha(40),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isEditing ? Icons.person_rounded : Icons.person_add_rounded,
                          color: Color(_selectedColor),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Benutzer bearbeiten' : 'Neuen Benutzer anlegen',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Stammdaten, Position & Gruppenzugehörigkeit',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name fields
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Vorname *',
                            hintText: 'z.B. Alexander',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (val) {
                            if ((val == null || val.trim().isEmpty) && _lastNameController.text.trim().isEmpty) {
                              return 'Bitte Namen eingeben';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nachname *',
                            hintText: 'z.B. Gohla',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (val) {
                            if ((val == null || val.trim().isEmpty) && _firstNameController.text.trim().isEmpty) {
                              return 'Bitte Namen eingeben';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-Mail-Adresse *',
                      hintText: 'alexander@firma.de',
                      prefixIcon: Icon(Icons.email_outlined),
                      helperText: 'Wird für Multi-Geräte-Login und Teilen verwendet',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Bitte E-Mail-Adresse eingeben';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Ungültige E-Mail-Adresse';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Position / Role
                  TextFormField(
                    controller: _positionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Position / Rolle im Unternehmen',
                      hintText: 'z.B. Bauleiter, Architekt, Projektleiter, Geschäftsführer',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Avatar Color Picker
                  Text(
                    'Profilfarbe:',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _avatarColors.map((colorVal) {
                      final isSelected = _selectedColor == colorVal;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = colorVal),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: Color(colorVal).withAlpha(160),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Groups section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gruppeneinteilung (Teams):',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Gruppe erstellen', style: TextStyle(fontSize: 12)),
                        onPressed: _addNewGroupPrompt,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isLoadingGroups)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableGroups.map((group) {
                        final isSelected = _selectedGroups.contains(group);
                        return FilterChip(
                          selected: isSelected,
                          avatar: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.group_outlined,
                            size: 16,
                            color: isSelected ? Colors.white : theme.colorScheme.primary,
                          ),
                          label: Text(group),
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedGroups.add(group);
                              } else {
                                _selectedGroups.remove(group);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      if (isEditing)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          tooltip: 'Benutzer löschen',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Benutzer löschen?'),
                                content: Text('Möchtest du "${widget.user!.fullName}" wirklich löschen?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Abbrechen'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Löschen', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await UserService.instance.deleteUser(widget.user!.id);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Abbrechen'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(isEditing ? 'Speichern' : 'Benutzer anlegen',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _save,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
