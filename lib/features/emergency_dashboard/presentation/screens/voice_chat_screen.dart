import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mesh_provider.dart';
import '../../../mesh_network/data/voice_service.dart';
import '../../../mesh_network/domain/voice_message.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/toast_service.dart';

/// Voice Message Chat Screen (Tap to record, tap to send)
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

  // Recording timer
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int _maxRecordingSeconds = 60;

  // Sent messages for UI (locally tracked)
  final List<VoiceMessage> _sentMessages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Toggle recording - tap to start, tap again to send
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    final started = await voiceService.startRecording();

    if (started) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _pulseController.repeat(reverse: true);

      // Start timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordingSeconds++);
        if (_recordingSeconds >= _maxRecordingSeconds) {
          _stopRecordingAndSend();
        }
      });
    } else {
      if (mounted) {
        ToastService.showError(
            'Could not start recording. Check microphone permission.');
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final voiceService = ref.read(voiceServiceProvider);
    final result = await voiceService.stopRecording();

    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    if (result == null) {
      HapticFeedback.lightImpact();
      if (mounted) {
        ToastService.showWarning('Recording too short (min 1 second)');
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
    _scrollToBottom();

    if (mounted) {
      ToastService.showSuccess(
          'Voice message sent (${voiceMessage.durationFormatted})');
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.cancelRecording();

    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
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

  String _formatRecordingTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final meshState = ref.watch(meshProvider);
    final incomingVoices = meshState.incomingVoiceMessages
        .where((m) => m.senderId == widget.peerId)
        .toList();

    // FIX: Filter out any incoming messages that we already have in _sentMessages
    // This prevents duplicates when our own sent message echoes back
    final sentIds = _sentMessages.map((m) => m.messageId).toSet();
    final filteredIncoming =
        incomingVoices.where((m) => !sentIds.contains(m.messageId)).toList();

    // Combine and sort all messages
    final allMessages = [...filteredIncoming, ..._sentMessages]
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
                          'Tap the mic button to record',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
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

          // Recording indicator bar
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.red.withOpacity(0.15),
              child: Row(
                children: [
                  // Pulsing recording dot
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(
                              0.6 + (_pulseController.value * 0.4)),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recording... ${_formatRecordingTime(_recordingSeconds)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Max ${_maxRecordingSeconds}s',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Bottom button area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Cancel button (only when recording)
                  if (_isRecording)
                    Expanded(
                      child: GestureDetector(
                        onTap: _cancelRecording,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline, color: Colors.white70),
                              SizedBox(width: 8),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_isRecording) const SizedBox(width: 12),

                  // Record / Send button
                  Expanded(
                    flex: _isRecording ? 1 : 1,
                    child: GestureDetector(
                      onTap: _toggleRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isRecording
                                ? [Colors.green, Colors.green.shade700]
                                : [
                                    const Color(0xFF667EEA),
                                    const Color(0xFF764BA2)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording
                                      ? Colors.green
                                      : const Color(0xFF667EEA))
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isRecording ? Icons.send : Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isRecording ? 'Send' : 'Record Voice Message',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
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
            const SizedBox(width: 10),

            // Waveform and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waveform visualization
                  Row(
                    children: List.generate(15, (index) {
                      final height = 6.0 + ((index * 3 + 5) % 7) * 3.0;
                      return Expanded(
                        child: Container(
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              isPlaying && index < 8 ? 0.9 : 0.4,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.mic,
                        size: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.durationFormatted,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
