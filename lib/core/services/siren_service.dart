import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class SirenService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _sirenFilePath;

  bool get isPlaying => _isPlaying;

  /// Generates a high-pitch siren WAV file effectively
  Future<String> _generateSirenFile() async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/emergency_siren.wav');

    // Return existing file if already generated
    if (await file.exists()) {
      return file.path;
    }

    // Audio parameters
    const int sampleRate = 44100;
    const double durationSeconds = 1.0; // 1 second loop
    final int numSamples = (sampleRate * durationSeconds).toInt();

    // WAV Header takes 44 bytes
    final int fileSize =
        44 + numSamples * 2; // 16-bit audio = 2 bytes per sample

    final ByteData byteData = ByteData(fileSize);
    int offset = 0;

    // --- WAV HEADER ---
    // ChunkID "RIFF"
    _writeString(byteData, offset, "RIFF");
    offset += 4;
    // ChunkSize
    byteData.setUint32(offset, fileSize - 8, Endian.little);
    offset += 4;
    // Format "WAVE"
    _writeString(byteData, offset, "WAVE");
    offset += 4;
    // Subchunk1ID "fmt "
    _writeString(byteData, offset, "fmt ");
    offset += 4;
    // Subchunk1Size (16 for PCM)
    byteData.setUint32(offset, 16, Endian.little);
    offset += 4;
    // AudioFormat (1 for PCM)
    byteData.setUint16(offset, 1, Endian.little);
    offset += 2;
    // NumChannels (1 for Mono)
    byteData.setUint16(offset, 1, Endian.little);
    offset += 2;
    // SampleRate
    byteData.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    // ByteRate (SampleRate * NumChannels * BitsPerSample/8)
    byteData.setUint32(offset, sampleRate * 2, Endian.little);
    offset += 4;
    // BlockAlign (NumChannels * BitsPerSample/8)
    byteData.setUint16(offset, 2, Endian.little);
    offset += 2;
    // BitsPerSample (16 bits)
    byteData.setUint16(offset, 16, Endian.little);
    offset += 2;
    // Subchunk2ID "data"
    _writeString(byteData, offset, "data");
    offset += 4;
    // Subchunk2Size (NumSamples * NumChannels * BitsPerSample/8)
    byteData.setUint32(offset, numSamples * 2, Endian.little);
    offset += 4;

    // --- DATA ---
    // Generate a chirp (sweep from 800Hz to 1500Hz)
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;

      // Frequency sweep: 880Hz to 1760Hz (A5 to A6) - Typical Alarm
      double freq = 880 + (880 * t);

      // Sine wave equation
      double sampleValue = sin(2 * pi * freq * t);

      // Convert -1.0..1.0 to 16-bit integer (-32768..32767)
      // Max volume directly
      int pcmValue = (sampleValue * 32767).toInt();

      byteData.setInt16(offset, pcmValue, Endian.little);
      offset += 2;
    }

    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file.path;
  }

  void _writeString(ByteData data, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  Future<void> startSiren() async {
    if (_isPlaying) return;

    try {
      _sirenFilePath ??= await _generateSirenFile();

      // Setup player
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0); // Max volume

      // Play
      await _audioPlayer.play(DeviceFileSource(_sirenFilePath!));
      _isPlaying = true;
    } catch (e) {
      print("Error playing siren: $e");
    }
  }

  Future<void> stopSiren() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      print("Error stopping siren: $e");
    }
  }
}
