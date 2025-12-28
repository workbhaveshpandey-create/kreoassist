import 'dart:convert';
import 'dart:typed_data';

/// Voice message model for PTT audio transmission over mesh network
class VoiceMessage {
  final String senderId;
  final String senderName;
  final String audioBase64; // Base64-encoded audio bytes
  final int durationMs;
  final DateTime timestamp;
  final String messageId;

  VoiceMessage({
    required this.senderId,
    required this.senderName,
    required this.audioBase64,
    required this.durationMs,
    required this.timestamp,
    required this.messageId,
  });

  /// Get audio bytes from base64
  Uint8List get audioBytes => base64Decode(audioBase64);

  /// Create from raw audio bytes
  factory VoiceMessage.fromBytes({
    required String senderId,
    required String senderName,
    required Uint8List audioBytes,
    required int durationMs,
    required String messageId,
  }) {
    return VoiceMessage(
      senderId: senderId,
      senderName: senderName,
      audioBase64: base64Encode(audioBytes),
      durationMs: durationMs,
      timestamp: DateTime.now(),
      messageId: messageId,
    );
  }

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'audioBase64': audioBase64,
        'durationMs': durationMs,
        'timestamp': timestamp.toIso8601String(),
        'messageId': messageId,
      };

  factory VoiceMessage.fromJson(Map<String, dynamic> json) => VoiceMessage(
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String? ?? 'Unknown',
        audioBase64: json['audioBase64'] as String,
        durationMs: json['durationMs'] as int? ?? 0,
        timestamp: DateTime.parse(json['timestamp'] as String),
        messageId: json['messageId'] as String,
      );

  /// Human-readable duration
  String get durationFormatted {
    final seconds = durationMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '0:${seconds.toString().padLeft(2, '0')}';
  }
}
