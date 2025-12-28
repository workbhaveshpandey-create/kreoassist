import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice recording and playback service for PTT functionality
class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  final _isRecordingController = StreamController<bool>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();

  /// Stream indicating if currently recording
  Stream<bool> get isRecordingStream => _isRecordingController.stream;

  /// Stream indicating if currently playing
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  bool _isRecording = false;
  bool _isPlaying = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  VoiceService() {
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _isPlayingController.add(false);
    });
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Start PTT recording
  /// Returns true if recording started successfully
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    // Check permission
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return false;
    }

    // Check if recorder is available
    if (!await _recorder.hasPermission()) {
      return false;
    }

    try {
      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/ptt_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Configure for voice: AAC, 16kHz, mono
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 64000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _recordingStartTime = DateTime.now();
      _isRecording = true;
      _isRecordingController.add(true);

      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the audio bytes with duration
  /// Returns null if no recording was in progress
  Future<({Uint8List bytes, int durationMs})?> stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _isRecordingController.add(false);

      if (path == null) return null;

      // Calculate duration
      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      // Read the recorded file
      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();

      // Clean up temp file
      await file.delete();
      _currentRecordingPath = null;
      _recordingStartTime = null;

      // Minimum valid recording (500ms)
      if (durationMs < 500) {
        print('Recording too short: ${durationMs}ms');
        return null;
      }

      return (bytes: bytes, durationMs: durationMs);
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      _isRecordingController.add(false);
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();
      _isRecording = false;
      _isRecordingController.add(false);

      // Delete temp file if exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _currentRecordingPath = null;
      _recordingStartTime = null;
    } catch (e) {
      print('Error cancelling recording: $e');
    }
  }

  /// Play audio from bytes
  Future<void> playAudio(Uint8List bytes) async {
    if (_isPlaying) {
      await stopPlayback();
    }

    try {
      // Write to temp file for playback
      final dir = await getTemporaryDirectory();
      final tempPath =
          '${dir.path}/play_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final file = File(tempPath);
      await file.writeAsBytes(bytes);

      _isPlaying = true;
      _isPlayingController.add(true);

      await _player.play(DeviceFileSource(tempPath));

      // Clean up after playback completes
      _player.onPlayerComplete.first.then((_) async {
        try {
          await file.delete();
        } catch (_) {}
      });
    } catch (e) {
      print('Error playing audio: $e');
      _isPlaying = false;
      _isPlayingController.add(false);
    }
  }

  /// Stop current playback
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _isPlayingController.add(false);
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _isRecordingController.close();
    _isPlayingController.close();
  }
}

/// Riverpod provider for VoiceService
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});
