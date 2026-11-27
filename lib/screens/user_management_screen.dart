import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/app_user.dart';
import '../services/ai_service.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';
import '../widgets/be_notiz_logo.dart';
import '../widgets/user_edit_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const UserManagementScreen({super.key, this.onLogout});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AppUser> _users = [];
  AppUser? _currentUser;
  List<String> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Gemini AI settings
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isSavingApiKey = false;
  final bool _showAISettings = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await UserService.instance.getUsers();
    final current = await UserService.instance.getCurrentUser();
    final groups = await UserService.instance.getAllGroups();
    final apiKey = await AIService.instance.getApiKey();

    setState(() {
      _users = users;
      _currentUser = current;
      _groups = groups;
      _apiKeyController.text = apiKey ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSavingApiKey = true);
    await AIService.instance.setApiKey(_apiKeyController.text.trim());
    setState(() => _isSavingApiKey = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini API-Schlüssel erfolgreich gespeichert!')),
      );
    }
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

  void _openUserEditDialog([AppUser? user]) async {
    final result = await showDialog<AppUser>(
      context: context,
      builder: (_) => UserEditDialog(user: user),
    );
    if (result != null) {
      await _loadData();
    }
  }

  void _switchUser(AppUser user) async {
    await UserService.instance.setCurrentUser(user);
    setState(() {
      _currentUser = user;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('👤 Profil gewechselt zu "${user.fullName}" (${user.position})'),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showMultiDeviceLoginDialog(AppUser user) async {
    final syncLink = await SyncService.instance.generateSyncLink();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sync_rounded, color: Color(0xFF1565C0)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Geräte-Synchronisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Benutzer: ${user.fullName} (${user.email})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Übertrage deine Daten (Notizen, Aufgaben & Konto) auf dein Zweitgerät:',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // Option 1: Live-Synchronisations-Link
                  const Text('Option 1: Synchronisations-Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162340) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF283B63) : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 20, color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            syncLink,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Sync-Link kopieren',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: syncLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 Synchronisations-Link kopiert!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons for Sharing
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Link senden'),
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text: 'BEnotiz Geräte-Synchronisation für ${user.fullName}:\n$syncLink',
                              subject: 'BEnotiz Synchronisation',
                            ),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Backup exportieren (JSON)'),
                        onPressed: () async {
                          final jsonStr = await SyncService.instance.exportDataJson();
                          await Clipboard.setData(ClipboardData(text: jsonStr));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('💾 Backup-Daten in Zwischenablage kopiert!')),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.upload_rounded, size: 16),
                        label: const Text('Daten importieren'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showImportDataDialog();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Auf dem Zweitgerät einfach den Link öffnen oder unter "Anmelden" die E-Mail und das Passwort eingeben.',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fertig'),
            ),
          ],
        );
      },
    );
  }

  void _showImportDataDialog() {
    final textCtrl = TextEditingController();
    bool isImporting = false;
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.download_rounded, color: Color(0xFF1565C0)),
              SizedBox(width: 10),
              Text('Daten importieren'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Füge hier den Synchronisations-Link, Code oder das JSON-Backup ein:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Sync-Daten / JSON einfügen',
                  hintText: 'https://.../#sync=... oder JSON',
                  prefixIcon: Icon(Icons.paste_rounded),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
              onPressed: isImporting
                  ? null
                  : () async {
                      final input = textCtrl.text.trim();
                      if (input.isEmpty) return;
                      setDialogState(() {
                        isImporting = true;
                        err = null;
                      });

                      String payload = input;
                      if (input.contains('#sync=')) {
                        payload = input.substring(input.indexOf('#sync=') + '#sync='.length);
                      } else if (input.contains('sync=')) {
                        payload = input.substring(input.indexOf('sync=') + 'sync='.length);
                      }
                      if (payload.contains('&')) {
                        payload = payload.substring(0, payload.indexOf('&'));
                      }

                      final res = await SyncService.instance.importSyncBundle(payload);
                      if (res.success && ctx.mounted) {
                        Navigator.pop(ctx);
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isImporting = false;
                          err = res.message;
                        });
                      }
                    },
              child: const Text('Importieren & Synchronisieren', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Abmelden?'),
          ],
        ),
        content: const Text(
          'Möchtest du dich wirklich abmelden? Du musst dich anschließend wieder mit deinem Passwort anmelden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await UserService.instance.logout();
              widget.onLogout?.call();
            },
            child: const Text('Abmelden', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEmailLoginPrompt() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.login_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 10),
            Text('Per E-Mail anmelden'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gib die E-Mail-Adresse deines Benutzerprofils ein, um dich auf diesem Gerät anzumelden:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-Mail-Adresse',
                hintText: 'name@firma.de',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                Navigator.pop(ctx);
                final user = await UserService.instance.loginWithEmail(email);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Angemeldet als ${user.fullName} (${user.email})'),
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                  );
                }
              }
            },
            child: const Text('Anmelden'),
          ),
        ],
      ),
    );
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
                await _loadData();
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

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            BENotizLogo(size: 30),
            SizedBox(width: 10),
            Text(
              'Team & Benutzer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.login_rounded),
            tooltip: 'Per E-Mail anmelden',
            onPressed: _showEmailLoginPrompt,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Daten importieren / synchronisieren',
            onPressed: _showImportDataDialog,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Neuen Benutzer anlegen',
            onPressed: () => _openUserEditDialog(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CURRENT LOGGED IN USER CARD
                    if (_currentUser != null) ...[
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: theme.colorScheme.primary.withAlpha(80), width: 1.5),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF132238), const Color(0xFF0F1A2C)]
                                  : [const Color(0xFFE8F1FC), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Color(_currentUser!.colorValue),
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      _currentUser!.initials,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Angemeldet auf diesem Gerät:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _currentUser!.fullName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (_currentUser!.position.isNotEmpty)
                                          Text(
                                            _currentUser!.position,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
                                            ),
                                          ),
                                        Text(
                                          _currentUser!.email,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_currentUser!.groups.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: _currentUser!.groups.map((g) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFD0E4FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '#$g',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0D47A1),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.sync_rounded, size: 16),
                                      label: const Text('Synchronisieren', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _showMultiDeviceLoginDialog(_currentUser!),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    label: const Text('Bearbeiten', style: TextStyle(fontSize: 12)),
                                    onPressed: () => _openUserEditDialog(_currentUser),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: isDark ? const Color(0xFF281C24) : Colors.red.shade50,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                                    tooltip: 'Abmelden',
                                    onPressed: _confirmLogout,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ACTION BAR: CREATE USER & SEARCH
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.person_add_rounded, size: 20),
                            label: const Text(
                              'Neuen Benutzer anlegen',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: () => _openUserEditDialog(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SEARCH FIELD
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Benutzer suchen (Vorname, Nachname, E-Mail, Position)...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 16),

                    // ALL USERS SECTION HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ANGELEGTE BENUTZER (${_filteredUsers.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Klick zum Wechseln / Bearbeiten',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // USERS LIST
                    if (_filteredUsers.isEmpty)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.person_search_rounded, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Kein Benutzer für "$_searchQuery" gefunden.'
                                      : 'Noch keine Benutzer angelegt.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._filteredUsers.map((user) {
                        final isCurrent = _currentUser?.id == user.id;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : (isDark ? const Color(0xFF283B63) : Colors.grey.shade200),
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openUserEditDialog(user),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Color(user.colorValue),
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      user.initials,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user.fullName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            if (isCurrent)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2E7D32),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Aktiv',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        if (user.position.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          user.email,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        if (user.groups.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: user.groups.map((g) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '#$g',
                                                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded),
                                    onSelected: (val) {
                                      if (val == 'switch') _switchUser(user);
                                      if (val == 'edit') _openUserEditDialog(user);
                                      if (val == 'multidevice') _showMultiDeviceLoginDialog(user);
                                      if (val == 'delete') {
                                        UserService.instance.deleteUser(user.id).then((_) => _loadData());
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      if (!isCurrent)
                                        const PopupMenuItem(
                                          value: 'switch',
                                          child: Row(
                                            children: [
                                              Icon(Icons.switch_account_rounded, size: 18, color: Color(0xFF1565C0)),
                                              SizedBox(width: 8),
                                              Text('Als dieser Benutzer anmelden'),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text('Bearbeiten'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'multidevice',
                                        child: Row(
                                          children: [
                                            Icon(Icons.devices_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text('Auf anderem Gerät anmelden'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Löschen', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 20),

                    // GROUPS SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GRUPPEN & ABTEILUNGEN (${_groups.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Gruppe anlegen', style: TextStyle(fontSize: 12)),
                          onPressed: _addNewGroupPrompt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Benutzer werden diesen Gruppen zugeordnet. Beim Verteilen von Aufgaben oder Teilen von Notizen kannst du direkt eine ganze Gruppe auswählen:',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _groups.map((group) {
                                final members = _users.where((u) => u.groups.contains(group)).toList();

                                return Chip(
                                  avatar: const CircleAvatar(
                                    backgroundColor: Color(0xFF1565C0),
                                    child: Icon(Icons.group, size: 12, color: Colors.white),
                                  ),
                                  label: Text('$group (${members.length})'),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('Gruppe "$group" entfernen?'),
                                        content: const Text('Die Gruppe wird aus allen Benutzern entfernt.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Entfernen', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await UserService.instance.deleteGroup(group);
                                      await _loadData();
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // GOOGLE GEMINI KI-AGENT SETTINGS (EXPANDABLE)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        initiallyExpanded: _showAISettings,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE3F2FD),
                          child: Icon(Icons.psychology_rounded, color: Color(0xFF1565C0)),
                        ),
                        title: const Text('Google Gemini KI-Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: const Text('API-Schlüssel für KI-Zusammenfassungen, OCR & Mathe', style: TextStyle(fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BEnotiz enthält leistungsfähige Offline-Engines für Mathe, Handschrifterkennung und NLP. Für optionale High-End Cloud-KI kannst du hier einen kostenlosen Gemini-Schlüssel hinterlegen:',
                                  style: TextStyle(fontSize: 12, height: 1.4),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _apiKeyController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Gemini API Key',
                                    hintText: 'AIzaSy...',
                                    prefixIcon: const Icon(Icons.key_rounded),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    helperText: 'Kostenlos auf aistudio.google.com erhältlich',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSavingApiKey ? null : _saveApiKey,
                                    icon: const Icon(Icons.save_rounded, size: 16),
                                    label: const Text('API-Key speichern'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
