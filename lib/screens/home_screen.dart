import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/note_template.dart';
import '../services/sharing_service.dart';
import '../services/storage_service.dart';
import '../widgets/be_notiz_logo.dart';
import '../widgets/note_card.dart';
import '../widgets/template_picker_dialog.dart';
import 'note_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pinned', 'shared', or specific '#tag'
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await StorageService.instance.loadNotes();
    setState(() {
      _allNotes = notes;
      _isLoading = false;
    });
  }

  Future<void> _togglePin(Note note) async {
    final updated = note.copyWith(isPinned: !note.isPinned);
    await StorageService.instance.saveOrUpdateNote(updated);
    await _loadNotes();
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notiz löschen?'),
        content: Text('Möchtest du "${note.title.isNotEmpty ? note.title : 'diese Notiz'}" wirklich löschen?'),
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
      await StorageService.instance.deleteNote(note.id);
      await _loadNotes();
    }
  }

  void _openNoteEditor([Note? note]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => NoteEditScreen(note: note)),
    );
    _loadNotes();
  }

  Future<void> _createNewNoteWithTemplate() async {
    final template = await showDialog<NoteTemplate>(
      context: context,
      builder: (ctx) => const TemplatePickerDialog(),
    );

    if (template != null && mounted) {
      final newNote = Note(
        id: const Uuid().v4(),
        title: template.defaultTitle,
        content: template.defaultContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        paperType: template.paperType,
        templateImageBase64: template.backgroundImageBase64,
      );
      _openNoteEditor(newNote);
    }
  }

  void _showJoinLinkDialog() {
    final linkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.blue),
            SizedBox(width: 10),
            Text('Per Link beitreten'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Füge einen Einladungs-Link ein, um eine freigegebene Notiz zu öffnen:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkCtrl,
              decoration: InputDecoration(
                hintText: 'https://benotiz.app/n/...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final link = linkCtrl.text.trim();
              if (link.isEmpty) return;
              Navigator.pop(ctx);

              final joinedNote = await SharingService.instance.joinNoteFromLink(link);
              if (joinedNote != null && mounted) {
                await _loadNotes();
                _openNoteEditor(joinedNote);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ungültiger oder nicht gefundener Einladungs-Link.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Öffnen'),
          ),
        ],
      ),
    );
  }

  List<Note> get _filteredNotes {
    return _allNotes.where((note) {
      final matchesSearch = _searchQuery.isEmpty ||
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));

      if (!matchesSearch) return false;

      if (_selectedFilter == 'pinned') {
        return note.isPinned;
      } else if (_selectedFilter == 'shared') {
        return note.isShared;
      } else if (_selectedFilter.startsWith('#')) {
        final tag = _selectedFilter.substring(1);
        return note.tags.contains(tag);
      }
      return true;
    }).toList();
  }

  Set<String> get _allTags {
    final set = <String>{};
    for (final note in _allNotes) {
      set.addAll(note.tags);
    }
    return set;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;
    final pinnedNotes = filtered.where((n) => n.isPinned).toList();
    final otherNotes = filtered.where((n) => !n.isPinned).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            BENotizLogo(size: 34),
            SizedBox(width: 12),
            Text(
              'BEnotiz',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          // Join by link button
          IconButton(
            icon: const Icon(Icons.add_link_rounded),
            tooltip: 'Per Link einladen / beitreten',
            onPressed: _showJoinLinkDialog,
          ),
          // Toggle Grid / List
          IconButton(
            icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Listenansicht' : 'Rasteransicht',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Benker Firmenlogo Wasserzeichen
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.08,
                        child: Image.asset(
                          'assets/images/benker_logo.png',
                          width: 380,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Notizen und Tags durchsuchen...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.withAlpha(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Alle'),
                        selected: _selectedFilter == 'all',
                        onSelected: (_) => setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.push_pin, size: 16),
                        label: const Text('Angeheftet'),
                        selected: _selectedFilter == 'pinned',
                        onSelected: (_) => setState(() => _selectedFilter = 'pinned'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.people_alt_rounded, size: 16),
                        label: const Text('Geteilt'),
                        selected: _selectedFilter == 'shared',
                        onSelected: (_) => setState(() => _selectedFilter = 'shared'),
                      ),
                      ..._allTags.map((tag) => Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: FilterChip(
                              label: Text('#$tag'),
                              selected: _selectedFilter == '#$tag',
                              onSelected: (_) => setState(() => _selectedFilter = '#$tag'),
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Notes list / grid
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadNotes,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = _isGridView
                                  ? (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 2))
                                  : 1;

                              return SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (pinnedNotes.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                                        child: Text(
                                          'ANGEHEFTET',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      _buildNotesGrid(pinnedNotes, crossAxisCount),
                                      const SizedBox(height: 24),
                                    ],
                                    if (otherNotes.isNotEmpty && pinnedNotes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                                        child: Text(
                                          'ANDERE',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    if (otherNotes.isNotEmpty) _buildNotesGrid(otherNotes, crossAxisCount),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_home_new_note',
        onPressed: _createNewNoteWithTemplate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Neue A4 Notiz'),
      ),
    );
  }

  Widget _buildNotesGrid(List<Note> notes, int crossAxisCount) {
    if (crossAxisCount == 1) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: notes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final note = notes[idx];
          return NoteCard(
            note: note,
            onTap: () => _openNoteEditor(note),
            onDelete: () => _deleteNote(note),
            onTogglePin: () => _togglePin(note),
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (ctx, idx) {
        final note = notes[idx];
        return NoteCard(
          note: note,
          onTap: () => _openNoteEditor(note),
          onDelete: () => _deleteNote(note),
          onTogglePin: () => _togglePin(note),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Keine passenden Notizen gefunden' : 'Noch keine Notizen vorhanden',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty ? 'Versuche einen anderen Suchbegriff' : 'Tippe auf "+", um deine erste Notiz zu schreiben',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _createNewNoteWithTemplate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Erste DIN A4 Notiz erstellen', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
