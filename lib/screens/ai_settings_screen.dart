import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/task_service.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  List<String> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final key = await AIService.instance.getApiKey();
    final groups = await TaskService.instance.getGroups();
    setState(() {
      _apiKeyController.text = key ?? '';
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSaving = true);
    await AIService.instance.setApiKey(_apiKeyController.text.trim());
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini API-Schlüssel erfolgreich gespeichert!')),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1565C0), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'KI-Agent & Gruppen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gemini Setup Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology_rounded, color: Color(0xFF1565C0), size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Google Gemini KI-Agent',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Der integrierte KI-Agent analysiert deine Notizen, transkribiert Sprachaufnahmen und extrahiert automatisch Aufgaben.',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _apiKeyController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Gemini API Key',
                              hintText: 'AIzaSy...',
                              prefixIcon: const Icon(Icons.key_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              helperText: 'Kostenlos erhältlich auf aistudio.google.com',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveApiKey,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Schlüssel speichern'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Capabilities
                  Text(
                    'Verfügbare KI-Funktionen',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureTile(
                    Icons.summarize_rounded,
                    'Text-Analyse & Zusammenfassungen',
                    'Lange Notizen mit einem Klick in prägnante Kernaussagen zusammenfassen.',
                    Colors.blue,
                  ),
                  _buildFeatureTile(
                    Icons.mic_rounded,
                    'Ton-Aufnahmen & Transkription',
                    'Sprachmemos aufnehmen, von der KI transkribieren und als Notiz sichern.',
                    Colors.red,
                  ),
                  _buildFeatureTile(
                    Icons.task_alt_rounded,
                    'Aufgaben-Erkennung',
                    'Erkennt To-Dos und Fristen in Notizen und Audio und legt sie automatisch an.',
                    Colors.green,
                  ),
                  _buildFeatureTile(
                    Icons.auto_fix_high_rounded,
                    'Schreibstil verbessern',
                    'Grammatik prüfen und Formulierungen automatisch optimieren.',
                    Colors.orange,
                  ),

                  const SizedBox(height: 24),

                  // Groups
                  Text(
                    'Verwaltete Gruppen',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _groups.map((group) {
                      return Chip(
                        avatar: const CircleAvatar(child: Icon(Icons.group, size: 14)),
                        label: Text(group),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String subtitle, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
