import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice recording and playback service for voice messages
class VoiceService {
  AudioRecorder? _recorder;
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
    print('🎤 Microphone permission status: $status');
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    print('🎤 Current microphone permission: $status');
    return status.isGranted;
  }

  /// Start recording
  /// Returns true if recording started successfully
  Future<bool> startRecording() async {
    if (_isRecording) {
      print('⚠️ Already recording');
      return false;
    }

    try {
      // Check/request permission
      if (!await hasPermission()) {
        print('🎤 Requesting microphone permission...');
        final granted = await requestPermission();
        if (!granted) {
          print('❌ Microphone permission denied');
          return false;
        }
      }

      // Create new recorder instance
      _recorder?.dispose();
      _recorder = AudioRecorder();

      // Get temp directory
      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      print('📁 Recording path: $_currentRecordingPath');

      // Start recording with AAC encoder
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100, // Higher quality
          bitRate: 128000, // Better bitrate
          numChannels: 1, // Mono
        ),
        path: _currentRecordingPath!,
      );

      _recordingStartTime = DateTime.now();
      _isRecording = true;
      _isRecordingController.add(true);

      print('✅ Recording started');
      return true;
    } catch (e, stack) {
      print('❌ Error starting recording: $e');
      print('Stack: $stack');
      _isRecording = false;
      _isRecordingController.add(false);
      return false;
    }
  }

  /// Stop recording and return the audio bytes with duration
  /// Returns null if no recording was in progress or if failed
  Future<({Uint8List bytes, int durationMs})?> stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null || _recorder == null) {
      print('⚠️ No active recording to stop');
      return null;
    }

    try {
      print('🛑 Stopping recording...');
      final path = await _recorder!.stop();
      _isRecording = false;
      _isRecordingController.add(false);

      print('📁 Recorded file path: $path');

      if (path == null || path.isEmpty) {
        print('❌ Recording returned null path');
        return null;
      }

      // Calculate duration
      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      print('⏱️ Recording duration: ${durationMs}ms');

      // Read the recorded file
      final file = File(path);
      if (!await file.exists()) {
        print('❌ Recording file does not exist: $path');
        return null;
      }

      final fileSize = await file.length();
      print('📦 File size: $fileSize bytes');

      if (fileSize < 100) {
        print('❌ Recording file too small');
        await file.delete();
        _currentRecordingPath = null;
        _recordingStartTime = null;
        return null;
      }

      final bytes = await file.readAsBytes();
      print('✅ Read ${bytes.length} bytes from recording');

      // Clean up temp file
      await file.delete();
      _currentRecordingPath = null;
      _recordingStartTime = null;

      // Minimum valid recording (1 second)
      if (durationMs < 1000) {
        print('⚠️ Recording too short: ${durationMs}ms (min 1000ms)');
        return null;
      }

      return (bytes: bytes, durationMs: durationMs);
    } catch (e, stack) {
      print('❌ Error stopping recording: $e');
      print('Stack: $stack');
      _isRecording = false;
      _isRecordingController.add(false);
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      print('🚫 Cancelling recording...');
      await _recorder?.stop();
      _isRecording = false;
      _isRecordingController.add(false);

      // Delete temp file if exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted temp recording file');
        }
      }
      _currentRecordingPath = null;
      _recordingStartTime = null;
    } catch (e) {
      print('❌ Error cancelling recording: $e');
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
      print('▶️ Playing audio from: $tempPath (${bytes.length} bytes)');

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
      print('❌ Error playing audio: $e');
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
      print('❌ Error stopping playback: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder?.dispose();
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
