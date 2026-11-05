import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioRecorder? _audioRecorder;
  String? _currentRecordingPath;
  bool _isRecording = false;

  AudioService._internal();

  AudioRecorder get recorder {
    _audioRecorder ??= AudioRecorder();
    return _audioRecorder!;
  }

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> hasPermission() async {
    try {
      return await recorder.hasPermission();
    } catch (_) {
      return true; // Fallback for desktop/unsupported check platforms
    }
  }

  Future<String?> startRecording() async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) return null;

      String filePath = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        final id = const Uuid().v4().substring(0, 8);
        filePath = '${dir.path}/note_audio_$id.m4a';
      }

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await recorder.start(config, path: filePath);
      _isRecording = true;
      _currentRecordingPath = filePath;
      return filePath;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return _currentRecordingPath;
      final path = await recorder.stop();
      _isRecording = false;
      _currentRecordingPath = path ?? _currentRecordingPath;
      return _currentRecordingPath;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await recorder.cancel();
      }
      _isRecording = false;
      if (_currentRecordingPath != null && !kIsWeb) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _currentRecordingPath = null;
    } catch (_) {}
  }

  void dispose() {
    _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
