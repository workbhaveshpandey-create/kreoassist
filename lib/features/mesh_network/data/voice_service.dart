import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

/// Simplified Voice Service with better reliability
class VoiceService {
  AudioRecorder? _recorder;
  AudioPlayer? _player;

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isRecording = false;
  bool _isPlaying = false;

  // Callback for when playback completes
  Function()? onPlaybackComplete;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  /// Initialize player
  void _ensurePlayer() {
    if (_player == null) {
      _player = AudioPlayer();
      _player!.onPlayerComplete.listen((_) {
        print('🔊 Playback completed');
        _isPlaying = false;
        onPlaybackComplete?.call();
      });
      _player!.onPlayerStateChanged.listen((state) {
        print('🔊 Player state: $state');
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _isPlaying = false;
        }
      });
    }
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    print('🎤 Microphone permission: $status');
    return status.isGranted;
  }

  /// Start recording
  Future<bool> startRecording() async {
    if (_isRecording) {
      print('⚠️ Already recording');
      return true; // Return true since we're already recording
    }

    try {
      // Request permission
      final hasPermission = await Permission.microphone.isGranted;
      if (!hasPermission) {
        final granted = await requestPermission();
        if (!granted) {
          print('❌ Permission denied');
          return false;
        }
      }

      // Create recorder
      _recorder?.dispose();
      _recorder = AudioRecorder();

      // Setup path
      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _recordingStartTime = DateTime.now();
      _isRecording = true;
      print('✅ Recording started: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('❌ Recording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and get bytes
  Future<({Uint8List bytes, int durationMs})?> stopRecording() async {
    if (!_isRecording) {
      print('⚠️ Not recording');
      return null;
    }

    try {
      final path = await _recorder?.stop();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        print('❌ No recording path');
        return null;
      }

      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      final file = File(path);
      if (!await file.exists()) {
        print('❌ File not found: $path');
        return null;
      }

      final bytes = await file.readAsBytes();
      print('✅ Recording stopped: ${bytes.length} bytes, ${durationMs}ms');

      // Cleanup file
      await file.delete().catchError((_) => file);
      _currentRecordingPath = null;
      _recordingStartTime = null;

      // Minimum 500ms
      if (durationMs < 500 || bytes.length < 100) {
        print('⚠️ Recording too short');
        return null;
      }

      return (bytes: bytes, durationMs: durationMs);
    } catch (e) {
      print('❌ Stop error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder?.stop();
      if (_currentRecordingPath != null) {
        await File(_currentRecordingPath!).delete().catchError((_) => File(''));
      }
    } catch (_) {}

    _isRecording = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;
    print('🚫 Recording cancelled');
  }

  /// Play audio from bytes
  Future<void> playAudio(Uint8List bytes) async {
    _ensurePlayer();

    try {
      // Stop any current playback
      if (_isPlaying) {
        await _player!.stop();
      }

      // Write to temp file
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/play_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final file = File(path);
      await file.writeAsBytes(bytes);

      _isPlaying = true;
      print('▶️ Playing: $path');

      await _player!.play(DeviceFileSource(path));

      // Cleanup after short delay
      Future.delayed(const Duration(seconds: 120), () async {
        try {
          await file.delete();
        } catch (_) {}
      });
    } catch (e) {
      print('❌ Play error: $e');
      _isPlaying = false;
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    try {
      await _player?.stop();
      _isPlaying = false;
      print('⏹️ Stopped playback');
    } catch (_) {}
  }

  /// Dispose
  void dispose() {
    _recorder?.dispose();
    _player?.dispose();
    _recorder = null;
    _player = null;
  }
}

/// Riverpod provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});
