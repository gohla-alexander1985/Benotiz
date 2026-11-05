import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/audio_service.dart';
import '../services/task_service.dart';

class AudioRecorderSheet extends StatefulWidget {
  final Function(String transcription) onTranscriptionComplete;

  const AudioRecorderSheet({
    super.key,
    required this.onTranscriptionComplete,
  });

  @override
  State<AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<AudioRecorderSheet> {
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _recordedPath;
  int _recordDurationSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _recordDurationSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDurationSeconds++;
      });
    });
  }

  Future<void> _startRecording() async {
    final path = await AudioService.instance.startRecording();
    if (path != null || AudioService.instance.isRecording) {
      setState(() {
        _isRecording = true;
        _recordedPath = path;
      });
      _startTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofon-Zugriff konnte nicht gestartet werden.')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await AudioService.instance.stopRecording();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });
  }

  Future<void> _analyzeWithAI() async {
    setState(() => _isAnalyzing = true);
    final result = await AIService.instance.analyzeAudio(filePath: _recordedPath);
    setState(() => _isAnalyzing = false);

    final transcript = result['transcript'] as String? ?? '';

    // Auto-extract tasks from transcription
    final extractedTasks = await AIService.instance.extractTasksFromText('Sprachaufnahme', transcript);
    if (extractedTasks.isNotEmpty) {
      await TaskService.instance.addTasks(extractedTasks);
    }

    widget.onTranscriptionComplete(transcript);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sprachnotiz analysiert & ${extractedTasks.length} Aufgabe(n) erstellt!',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mic_rounded,
                color: _isRecording ? Colors.red : theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                _isRecording
                    ? 'Aufnahme läuft...'
                    : (_isAnalyzing ? 'KI analysiert Audio...' : 'Aufnahme beendet'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Duration Timer
          Text(
            _formatDuration(_recordDurationSeconds),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: _isRecording ? Colors.red.shade600 : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          if (_isAnalyzing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Transkribiere Sprache und extrahiere Aufgaben...',
              style: TextStyle(color: Colors.grey),
            ),
          ] else if (_isRecording) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    _timer?.cancel();
                    await AudioService.instance.cancelRecording();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Verwerfen'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stopp & Analysieren'),
                ),
              ],
            ),
          ] else ...[
            // Finished recording actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await AudioService.instance.cancelRecording();
                    _startRecording();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Neu aufnehmen'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _analyzeWithAI,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Mit KI transkribieren'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
