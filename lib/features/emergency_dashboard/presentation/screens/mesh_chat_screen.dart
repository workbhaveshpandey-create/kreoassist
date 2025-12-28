import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/mesh_provider.dart';
import '../../../mesh_network/data/voice_service.dart';
import '../../../mesh_network/domain/voice_message.dart';
import 'package:uuid/uuid.dart';

class MeshChatScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String peerName;

  const MeshChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
  });

  @override
  ConsumerState<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends ConsumerState<MeshChatScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  // Chat messages (text + voice markers)
  final List<_ChatItem> _chatItems = [];
  bool _isLoading = true;

  // Voice recording state
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  late AnimationController _waveController;

  // Voice playback
  String? _playingMessageId;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meshProvider.notifier).consumeMessagesForPeer(widget.peerId);
      ref
          .read(meshProvider.notifier)
          .consumeVoiceMessagesForPeer(widget.peerId);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _waveController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mesh_chat_${widget.peerId}';
    final history = prefs.getStringList(key);
    if (history != null && mounted) {
      setState(() {
        for (final msg in history) {
          _chatItems.add(_ChatItem.text(msg, msg.startsWith("Me:")));
        }
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
    _scrollToBottom();
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

  Future<void> _saveTextMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mesh_chat_${widget.peerId}';
    List<String> history = prefs.getStringList(key) ?? [];
    history.add(message);
    await prefs.setStringList(key, history);
  }

  Future<void> _sendTextMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(meshProvider.notifier).sendMessage(widget.peerId, text);

    final newMsg = "Me: $text";
    setState(() => _chatItems.add(_ChatItem.text(newMsg, true)));
    await _saveTextMessage(newMsg);

    _controller.clear();
    _scrollToBottom();
  }

  // ============ VOICE RECORDING ============

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
      _waveController.repeat(reverse: true);

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordingSeconds++);
          if (_recordingSeconds >= 60) {
            _stopRecordingAndSend();
          }
        }
      });
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

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final voiceService = ref.read(voiceServiceProvider);
    final result = await voiceService.stopRecording();

    _waveController.stop();
    _waveController.reset();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    if (result == null) {
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording too short (min 1 second)'),
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

    // Add to chat
    setState(() {
      _chatItems.add(_ChatItem.voice(voiceMessage, true));
    });
    _scrollToBottom();
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.cancelRecording();

    _waveController.stop();
    _waveController.reset();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _playVoice(VoiceMessage message) async {
    final voiceService = ref.read(voiceServiceProvider);

    if (_playingMessageId == message.messageId) {
      await voiceService.stopPlayback();
      setState(() => _playingMessageId = null);
      return;
    }

    setState(() => _playingMessageId = message.messageId);
    await voiceService.playAudio(message.audioBytes);
    if (mounted) {
      setState(() => _playingMessageId = null);
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Listen for incoming text messages
    ref.listen<List<MeshMessage>>(
      meshProvider.select((s) => s.incomingMessages),
      (previous, next) {
        final newMessages =
            next.where((m) => m.senderId == widget.peerId).toList();
        if (newMessages.isNotEmpty) {
          for (final msg in newMessages) {
            setState(() => _chatItems.add(
                _ChatItem.text("${widget.peerName}: ${msg.message}", false)));
          }
          _scrollToBottom();
          ref.read(meshProvider.notifier).consumeMessagesForPeer(widget.peerId);
        }
      },
    );

    // Listen for incoming voice messages
    ref.listen<List<VoiceMessage>>(
      meshProvider.select((s) => s.incomingVoiceMessages),
      (previous, next) {
        final newVoices =
            next.where((m) => m.senderId == widget.peerId).toList();
        if (newVoices.isNotEmpty) {
          for (final voice in newVoices) {
            setState(() => _chatItems.add(_ChatItem.voice(voice, false)));
          }
          _scrollToBottom();
          ref
              .read(meshProvider.notifier)
              .consumeVoiceMessagesForPeer(widget.peerId);
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Chat messages
          Expanded(child: _buildMessagesList()),

          // Recording indicator
          if (_isRecording) _buildRecordingBar(),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.peerName.isNotEmpty
                    ? widget.peerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer(builder: (context, ref, _) {
                  final isConnected = ref.watch(meshProvider.select((s) =>
                      s.connectedEndpoints.contains(widget.peerId) ||
                      s.endpointToUserId.containsValue(widget.peerId)));
                  return Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? "Online" : "Offline",
                        style: TextStyle(
                          fontSize: 12,
                          color: isConnected ? Colors.green : Colors.white38,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chatItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text("No messages yet",
                style: TextStyle(color: Colors.white38, fontSize: 15)),
            const SizedBox(height: 4),
            const Text("Send a message or voice note!",
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _chatItems.length,
      itemBuilder: (context, index) {
        final item = _chatItems[index];
        if (item.isVoice) {
          return _VoiceBubble(
            message: item.voiceMessage!,
            isMe: item.isMe,
            isPlaying: _playingMessageId == item.voiceMessage!.messageId,
            onPlay: () => _playVoice(item.voiceMessage!),
          );
        } else {
          return _TextBubble(text: item.textContent!, isMe: item.isMe);
        }
      },
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.withOpacity(0.15),
      child: Row(
        children: [
          // Live waveform
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Row(
                children: List.generate(20, (i) {
                  final random = Random(i);
                  final baseHeight = 4 + random.nextDouble() * 16;
                  final animatedHeight =
                      baseHeight * (0.5 + _waveController.value * 0.5);
                  return Container(
                    width: 3,
                    height: animatedHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            _formatTime(_recordingSeconds),
            style: const TextStyle(
                color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Voice record button
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isRecording
                        ? [Colors.green, Colors.green.shade700]
                        : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording
                              ? Colors.green
                              : const Color(0xFF667EEA))
                          .withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.send : Icons.mic,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send text button
            Material(
              color: const Color(0xFF00BCD4),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _controller.text.trim().isNotEmpty
                    ? _sendTextMessage
                    : null,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ HELPER CLASSES ============

class _ChatItem {
  final bool isVoice;
  final bool isMe;
  final String? textContent;
  final VoiceMessage? voiceMessage;

  _ChatItem._(
      {required this.isVoice,
      required this.isMe,
      this.textContent,
      this.voiceMessage});

  factory _ChatItem.text(String text, bool isMe) =>
      _ChatItem._(isVoice: false, isMe: isMe, textContent: text);
  factory _ChatItem.voice(VoiceMessage voice, bool isMe) =>
      _ChatItem._(isVoice: true, isMe: isMe, voiceMessage: voice);
}

class _TextBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _TextBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final content = isMe
        ? text.substring(4)
        : text.contains(':')
            ? text.split(':').sublist(1).join(':').trim()
            : text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF00BCD4) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Text(content,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.3)),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  final VoiceMessage message;
  final bool isMe;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _VoiceBubble(
      {required this.message,
      required this.isMe,
      required this.isPlaying,
      required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe
                ? const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)])
                : null,
            color: isMe ? null : const Color(0xFF2A2A2A),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Animated waveform
              Expanded(
                child: _AnimatedWaveform(isPlaying: isPlaying),
              ),
              const SizedBox(width: 8),

              // Duration
              Text(
                message.durationFormatted,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedWaveform extends StatefulWidget {
  final bool isPlaying;
  const _AnimatedWaveform({required this.isPlaying});

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(12, (i) {
            final random = Random(i * 7);
            final baseHeight = 6 + random.nextDouble() * 14;
            final height = widget.isPlaying
                ? baseHeight * (0.4 + _controller.value * 0.6)
                : baseHeight * 0.5;
            return Container(
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(widget.isPlaying ? 0.9 : 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
