import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mesh_provider.dart';
import '../../../mesh_network/data/voice_service.dart';
import '../../../mesh_network/domain/voice_message.dart';
import 'package:uuid/uuid.dart';

/// Push-to-Talk Voice Chat Screen
class VoiceChatScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String peerName;

  const VoiceChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
  });

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentlyPlayingId;
  final _uuid = const Uuid();

  // Sent messages for UI (locally tracked)
  final List<VoiceMessage> _sentMessages = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    final started = await voiceService.startRecording();

    if (started) {
      HapticFeedback.mediumImpact();
      setState(() => _isRecording = true);
      _pulseController.repeat(reverse: true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not start recording. Check microphone permission.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    final voiceService = ref.read(voiceServiceProvider);
    final result = await voiceService.stopRecording();

    _pulseController.stop();
    setState(() => _isRecording = false);

    if (result == null) {
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording too short or failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    HapticFeedback.heavyImpact();

    // Create voice message
    final voiceMessage = VoiceMessage.fromBytes(
      senderId: 'me',
      senderName: 'You',
      audioBytes: result.bytes,
      durationMs: result.durationMs,
      messageId: _uuid.v4(),
    );

    // Send to peer
    ref
        .read(meshProvider.notifier)
        .sendVoiceMessage(widget.peerId, voiceMessage);

    // Add to sent messages for UI
    setState(() {
      _sentMessages.add(voiceMessage);
    });
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.cancelRecording();

    _pulseController.stop();
    setState(() => _isRecording = false);
    HapticFeedback.lightImpact();
  }

  Future<void> _playVoice(VoiceMessage message) async {
    final voiceService = ref.read(voiceServiceProvider);

    if (_isPlaying && _currentlyPlayingId == message.messageId) {
      await voiceService.stopPlayback();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = null;
      });
      return;
    }

    setState(() {
      _isPlaying = true;
      _currentlyPlayingId = message.messageId;
    });

    await voiceService.playAudio(message.audioBytes);

    // Reset after playback
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meshState = ref.watch(meshProvider);
    final incomingVoices = meshState.incomingVoiceMessages
        .where((m) => m.senderId == widget.peerId)
        .toList();

    // Combine and sort all messages
    final allMessages = [...incomingVoices, ..._sentMessages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  widget.peerName.isNotEmpty
                      ? widget.peerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: meshState.onlinePeers.contains(widget.peerId)
                            ? Colors.green
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      meshState.onlinePeers.contains(widget.peerId)
                          ? 'Online'
                          : 'Offline',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: allMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none_rounded,
                          size: 80,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No voice messages yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hold the microphone button to record',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: allMessages.length,
                    itemBuilder: (context, index) {
                      final message = allMessages[index];
                      final isMe = message.senderId == 'me';
                      return _VoiceMessageBubble(
                        message: message,
                        isMe: isMe,
                        isPlaying: _currentlyPlayingId == message.messageId,
                        onPlay: () => _playVoice(message),
                      );
                    },
                  ),
          ),

          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 12 + (_pulseController.value * 4),
                        height: 12 + (_pulseController.value * 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(
                              0.8 + (_pulseController.value * 0.2)),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recording... Release to send',
                    style: TextStyle(
                      color: Colors.red[300],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // PTT Button area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cancel button (only visible when recording)
                if (_isRecording)
                  GestureDetector(
                    onTap: _cancelRecording,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                if (_isRecording) const SizedBox(width: 32),

                // Main PTT button
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecordingAndSend(),
                  onLongPressCancel: _cancelRecording,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = _isRecording
                          ? 1.0 + (_pulseController.value * 0.1)
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isRecording
                                  ? [Colors.red, Colors.red.shade700]
                                  : [
                                      const Color(0xFF667EEA),
                                      const Color(0xFF764BA2)
                                    ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording
                                        ? Colors.red
                                        : const Color(0xFF667EEA))
                                    .withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Voice message bubble widget
class _VoiceMessageBubble extends StatelessWidget {
  final VoiceMessage message;
  final bool isMe;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _VoiceMessageBubble({
    required this.message,
    required this.isMe,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                )
              : null,
          color: isMe ? null : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play button
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isMe ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Waveform placeholder and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waveform visualization
                  Row(
                    children: List.generate(12, (index) {
                      final height = 8.0 + (index % 4) * 6.0;
                      return Expanded(
                        child: Container(
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              isPlaying && index < 6 ? 0.9 : 0.4,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.durationFormatted,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
