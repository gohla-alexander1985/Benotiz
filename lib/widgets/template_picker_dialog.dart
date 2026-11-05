import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note_template.dart';
import '../services/template_service.dart';

class TemplatePickerDialog extends StatefulWidget {
  final ValueChanged<NoteTemplate> onTemplateSelected;

  const TemplatePickerDialog({
    super.key,
    required this.onTemplateSelected,
  });

  @override
  State<TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends State<TemplatePickerDialog> {
  List<NoteTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await TemplateService.instance.loadAllTemplates();
    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  Future<void> _uploadCustomTemplate() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
    if (picked == null) return;

    final nameCtrl = TextEditingController(text: 'Eigene A4-Vorlage');
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vorlage benennen'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name der Vorlage'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hochladen & Speichern'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      final newTemplate = NoteTemplate.custom(
        name: nameCtrl.text.trim(),
        description: 'Benutzerdefinierte hochgeladene A4-Vorlage',
        paperType: 'custom',
        backgroundImageBase64: base64Image,
      );

      await TemplateService.instance.saveCustomTemplate(newTemplate);
      widget.onTemplateSelected(newTemplate);
      if (mounted) Navigator.pop(context);
    }
  }

  IconData _getIconForType(String paperType) {
    switch (paperType) {
      case 'grid':
        return Icons.grid_4x4_rounded;
      case 'lined':
        return Icons.format_align_justify_rounded;
      case 'dots':
        return Icons.grain_rounded;
      case 'cornell':
        return Icons.school_rounded;
      case 'meeting':
        return Icons.groups_rounded;
      case 'planner':
        return Icons.calendar_month_rounded;
      case 'custom':
        return Icons.image_rounded;
      case 'blank':
      default:
        return Icons.crop_portrait_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.style_rounded, color: Color(0xFF1565C0), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DIN A4 Notizvorlage wählen',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Wähle ein A4-Papierlayout oder lade eine eigene Vorlage hoch',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Upload Custom Template Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF1565C0)),
                  label: const Text(
                    '+ Eigene Vorlage (PDF / Bild) hochladen',
                    style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                  ),
                  onPressed: _uploadCustomTemplate,
                ),
              ),
              const SizedBox(height: 16),

              // Template Grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        itemCount: _templates.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.35,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (ctx, idx) {
                          final template = _templates[idx];
                          final icon = _getIconForType(template.paperType);

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                widget.onTemplateSelected(template);
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD0E4FF),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(icon, size: 18, color: const Color(0xFF1565C0)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            template.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (template.isCustom)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () async {
                                              await TemplateService.instance.deleteCustomTemplate(template.id);
                                              _loadTemplates();
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      template.description,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
