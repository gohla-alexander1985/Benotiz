import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegisterMode = true; // true = Register, false = Login
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _positionController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      if (_isRegisterMode) {
        final fullName = _nameController.text.trim();
        final nameParts = fullName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        final position = _positionController.text.trim();

        await UserService.instance.registerUser(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          position: position.isNotEmpty ? position : 'Mitarbeiter',
        );

        if (mounted) {
          setState(() => _isLoading = false);
          widget.onAuthenticated();
        }
      } else {
        // Login mode
        final user = await UserService.instance.loginWithCredentials(
          email: email,
          password: password,
        );

        if (user == null) {
          setState(() {
            _errorMessage = 'E-Mail oder Passwort ist falsch. Bitte überprüfe deine Eingaben.';
            _isLoading = false;
          });
          return;
        }

        if (mounted) {
          setState(() => _isLoading = false);
          widget.onAuthenticated();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ein Fehler ist aufgetreten: $e';
        _isLoading = false;
      });
    }
  }

  void _showPasteSyncLinkDialog() {
    final linkController = TextEditingController();
    bool isImporting = false;
    String? importError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.devices_rounded, color: Color(0xFF1565C0)),
              SizedBox(width: 10),
              Text('Geräte-Kopplung / Link'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Füge hier den Synchronisations-Link oder Code ein, den du auf deinem Erstgerät erstellt hast:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'https://.../#sync=... oder Sync-Code einfügen',
                  labelText: 'Kopplungs-Link oder Code',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              if (importError != null) ...[
                const SizedBox(height: 8),
                Text(importError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
              icon: isImporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text('Übertragen & Anmelden', style: TextStyle(color: Colors.white)),
              onPressed: isImporting
                  ? null
                  : () async {
                      final input = linkController.text.trim();
                      if (input.isEmpty) return;

                      setDialogState(() {
                        isImporting = true;
                        importError = null;
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

                      final result = await SyncService.instance.importSyncBundle(payload);

                      if (result.success && ctx.mounted) {
                        Navigator.pop(ctx);
                        widget.onAuthenticated();
                      } else {
                        setDialogState(() {
                          isImporting = false;
                          importError = result.message;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryBlue = theme.colorScheme.primary;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon & Header
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'BE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'notiz',
                            style: TextStyle(
                              color: Colors.lightBlue.shade100,
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Headline
                  Text(
                    'BEnotiz',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : const Color(0xFF0D253F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegisterMode
                        ? 'Konto erstellen & auf allen Geräten nutzen'
                        : 'Auf diesem Gerät anmelden',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode Selector Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162340) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() {
                              _isRegisterMode = true;
                              _errorMessage = null;
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isRegisterMode
                                    ? (isDark ? const Color(0xFF1E88E5) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isRegisterMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Konto erstellen',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _isRegisterMode
                                      ? (_isDark(isDark) ? Colors.white : primaryBlue)
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() {
                              _isRegisterMode = false;
                              _errorMessage = null;
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isRegisterMode
                                    ? (isDark ? const Color(0xFF1E88E5) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isRegisterMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Anmelden',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: !_isRegisterMode
                                      ? (_isDark(isDark) ? Colors.white : primaryBlue)
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Fields
                  if (_isRegisterMode) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Vollständiger Name *',
                        hintText: 'z. B. Alexander Gohla',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Bitte gib deinen Namen ein.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-Mail-Adresse *',
                      hintText: 'name@beispiel.de',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Bitte gib deine E-Mail-Adresse ein.';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Bitte gib eine gültige E-Mail-Adresse ein.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Passwort *',
                      hintText: 'Mindestens 6 Zeichen',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Bitte gib ein Passwort ein.';
                      }
                      if (val.length < 6) {
                        return 'Das Passwort muss mindestens 6 Zeichen lang sein.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  if (_isRegisterMode) ...[
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Passwort wiederholen *',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (val) {
                        if (val != _passwordController.text) {
                          return 'Die Passwörter stimmen nicht überein.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _positionController,
                      decoration: const InputDecoration(
                        labelText: 'Position / Abteilung (optional)',
                        hintText: 'z. B. Projektleiter, Bauleitung',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 10),
                  ],

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _isRegisterMode ? 'Konto erstellen & App starten' : 'Anmelden & Synchronisieren',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  // Cross-device sync options for returning users
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'GERÄTE-SYNCHRONISATION',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: isDark ? const Color(0xFF283B63) : const Color(0xFF90CAF9)),
                    ),
                    icon: const Icon(Icons.devices_rounded, size: 20, color: Color(0xFF1565C0)),
                    label: const Text(
                      'Mit Erstgerät koppeln (Link oder Code)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _showPasteSyncLinkDialog,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    '🔒 Deine Notizen und Aufgaben sind lokal und sicher verschlüsselt gespeichert und können jederzeit zwischen deinen Geräten synchronisiert werden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isDark(bool isDark) => isDark;
}
