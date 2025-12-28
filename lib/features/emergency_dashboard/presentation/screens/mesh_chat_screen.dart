import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/mesh_provider.dart';
import '../../../mesh_network/data/voice_service.dart';
import '../../../mesh_network/domain/voice_message.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/toast_service.dart';

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

class _MeshChatScreenState extends ConsumerState<MeshChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  // All chat items (persisted)
  final List<_ChatItem> _items = [];
  bool _isLoading = true;

  // Recording state
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // Playback state
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load chat history (text + voice)
  Future<void> _loadChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load text messages
      final textKey = 'chat_text_${widget.peerId}';
      final texts = prefs.getStringList(textKey) ?? [];

      // Load voice messages metadata
      final voiceKey = 'chat_voice_${widget.peerId}';
      final voiceJson = prefs.getStringList(voiceKey) ?? [];

      // Parse text messages
      for (final text in texts) {
        final isMe = text.startsWith('Me:');
        _items.add(_ChatItem(
          id: _uuid.v4(),
          isVoice: false,
          isMe: isMe,
          text: text,
          timestamp: DateTime.now(),
        ));
      }

      // Parse and load voice messages
      final voiceDir = await _getVoiceDir();
      for (final json in voiceJson) {
        try {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final file = File('${voiceDir.path}/${data['id']}.m4a');
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            _items.add(_ChatItem(
              id: data['id'] as String,
              isVoice: true,
              isMe: data['isMe'] as bool,
              durationMs: data['durationMs'] as int,
              audioBytes: bytes,
              timestamp: DateTime.parse(data['timestamp'] as String),
            ));
          }
        } catch (e) {
          print('Error loading voice: $e');
        }
      }

      // Sort by timestamp
      _items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    } catch (e) {
      print('Error loading chat: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Directory> _getVoiceDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${appDir.path}/voice_messages');
    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }
    return voiceDir;
  }

  /// Save a text message
  Future<void> _saveTextMessage(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_text_${widget.peerId}';
    final list = prefs.getStringList(key) ?? [];
    list.add(text);
    await prefs.setStringList(key, list);
  }

  /// Save a voice message
  Future<void> _saveVoiceMessage(_ChatItem item) async {
    try {
      // Save audio file
      final voiceDir = await _getVoiceDir();
      final file = File('${voiceDir.path}/${item.id}.m4a');
      await file.writeAsBytes(item.audioBytes!);

      // Save metadata
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_voice_${widget.peerId}';
      final list = prefs.getStringList(key) ?? [];
      list.add(jsonEncode({
        'id': item.id,
        'isMe': item.isMe,
        'durationMs': item.durationMs,
        'timestamp': item.timestamp.toIso8601String(),
      }));
      await prefs.setStringList(key, list);

      // FIX: Ensure this peer appears in the "Chat List" (which relies on 'mesh_chat_...' key)
      // Even if we don't store text, the key must exist for the list screen to find it.
      final mainKey = 'mesh_chat_${widget.peerId}';
      if (!prefs.containsKey(mainKey)) {
        await prefs.setStringList(mainKey, []);
      }
    } catch (e) {
      print('Error saving voice: $e');
    }
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

  /// Send text message
  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final item = _ChatItem(
      id: _uuid.v4(),
      isVoice: false,
      isMe: true,
      text: 'Me: $text',
      timestamp: DateTime.now(),
    );

    setState(() => _items.add(item));
    await _saveTextMessage(item.text!);

    ref.read(meshProvider.notifier).sendMessage(widget.peerId, text);
    _scrollToBottom();
  }

  /// Start voice recording
  Future<void> _startRecording() async {
    if (_isRecording) return;

    final voiceService = ref.read(voiceServiceProvider);
    final started = await voiceService.startRecording();

    if (started) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() => _recordingSeconds++);
          if (_recordingSeconds >= 60) _stopAndSend();
        }
      });
    } else {
      _showError('Cannot record. Check microphone permission.');
    }
  }

  /// Stop recording and send
  Future<void> _stopAndSend() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    setState(() => _isRecording = false);

    final voiceService = ref.read(voiceServiceProvider);
    final result = await voiceService.stopRecording();

    if (result == null) {
      _showError('Recording too short');
      return;
    }

    HapticFeedback.heavyImpact();

    final item = _ChatItem(
      id: _uuid.v4(),
      isVoice: true,
      isMe: true,
      durationMs: result.durationMs,
      audioBytes: result.bytes,
      timestamp: DateTime.now(),
    );

    setState(() {
      _items.add(item);
      _recordingSeconds = 0;
    });

    // Save locally
    await _saveVoiceMessage(item);

    // Send via mesh
    final voiceMsg = VoiceMessage.fromBytes(
      senderId: 'me',
      senderName: 'You',
      audioBytes: result.bytes,
      durationMs: result.durationMs,
      messageId: item.id,
    );
    ref.read(meshProvider.notifier).sendVoiceMessage(widget.peerId, voiceMsg);

    _scrollToBottom();
  }

  /// Cancel recording
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.cancelRecording();

    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    HapticFeedback.lightImpact();
  }

  /// Play voice message
  Future<void> _playVoice(_ChatItem item) async {
    final voiceService = ref.read(voiceServiceProvider);

    // If already playing this, stop
    if (_playingId == item.id) {
      await voiceService.stopPlayback();
      setState(() => _playingId = null);
      return;
    }

    // Stop any current playback
    if (_playingId != null) {
      await voiceService.stopPlayback();
    }

    setState(() => _playingId = item.id);

    // Setup completion callback
    voiceService.onPlaybackComplete = () {
      if (mounted) setState(() => _playingId = null);
    };

    await voiceService.playAudio(item.audioBytes!);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ToastService.showWarning(msg);
  }

  String _formatDuration(int ms) {
    final secs = (ms / 1000).round();
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Listen for incoming text messages
    ref.listen<List<MeshMessage>>(
      meshProvider.select((s) => s.incomingMessages),
      (_, next) {
        final newMsgs = next.where((m) => m.senderId == widget.peerId).toList();
        for (final msg in newMsgs) {
          final item = _ChatItem(
            id: _uuid.v4(),
            isVoice: false,
            isMe: false,
            text: '${widget.peerName}: ${msg.message}',
            timestamp: DateTime.now(),
          );
          setState(() => _items.add(item));
          _saveTextMessage(item.text!);
        }
        if (newMsgs.isNotEmpty) {
          ref.read(meshProvider.notifier).consumeMessagesForPeer(widget.peerId);
          _scrollToBottom();
        }
      },
    );

    // Listen for incoming voice messages
    ref.listen<List<VoiceMessage>>(
      meshProvider.select((s) => s.incomingVoiceMessages),
      (_, next) {
        final newVoices =
            next.where((m) => m.senderId == widget.peerId).toList();
        for (final voice in newVoices) {
          final item = _ChatItem(
            id: voice.messageId,
            isVoice: true,
            isMe: false,
            durationMs: voice.durationMs,
            audioBytes: voice.audioBytes,
            timestamp: DateTime.now(),
          );
          setState(() => _items.add(item));
          _saveVoiceMessage(item);
        }
        if (newVoices.isNotEmpty) {
          ref
              .read(meshProvider.notifier)
              .consumeVoiceMessagesForPeer(widget.peerId);
          _scrollToBottom();
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (_isRecording) _buildRecordingBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.peerName.isNotEmpty
                    ? widget.peerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(widget.peerName, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        if (item.isVoice) {
          return _VoiceBubble(
            item: item,
            isPlaying: _playingId == item.id,
            onTap: () => _playVoice(item),
            formatDuration: _formatDuration,
          );
        }
        return _TextBubble(item: item);
      },
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 10),
          Text(
            'Recording ${_formatDuration(_recordingSeconds * 1000)}',
            style:
                const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _cancelRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    // Listen to text changes for button state
    return StatefulBuilder(
      builder: (context, setLocalState) {
        // Determine button state
        final hasText = _controller.text.trim().isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF1E1E1E),
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
                        hintText: 'Type or tap mic...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Single smart button
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      // Recording -> Send voice
                      _stopAndSend();
                    } else if (hasText) {
                      // Has text -> Send text
                      _sendText();
                      setLocalState(() {});
                    } else {
                      // Empty -> Start recording
                      _startRecording();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isRecording
                            ? [Colors.green, Colors.green.shade700]
                            : hasText
                                ? [
                                    const Color(0xFF00BCD4),
                                    const Color(0xFF0097A7)
                                  ]
                                : [
                                    const Color(0xFF667EEA),
                                    const Color(0xFF764BA2)
                                  ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording
                                  ? Colors.green
                                  : hasText
                                      ? const Color(0xFF00BCD4)
                                      : const Color(0xFF667EEA))
                              .withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording
                          ? Icons.send
                          : hasText
                              ? Icons.send
                              : Icons.mic,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============ DATA CLASSES ============

class _ChatItem {
  final String id;
  final bool isVoice;
  final bool isMe;
  final String? text;
  final int? durationMs;
  final Uint8List? audioBytes;
  final DateTime timestamp;

  _ChatItem({
    required this.id,
    required this.isVoice,
    required this.isMe,
    this.text,
    this.durationMs,
    this.audioBytes,
    required this.timestamp,
  });
}

// ============ WIDGETS ============

class _TextBubble extends StatelessWidget {
  final _ChatItem item;
  const _TextBubble({required this.item});

  @override
  Widget build(BuildContext context) {
    final content = item.isMe
        ? item.text!.replaceFirst('Me: ', '')
        : item.text!.contains(':')
            ? item.text!.split(':').sublist(1).join(':').trim()
            : item.text!;

    final time = TimeOfDay.fromDateTime(item.timestamp).format(context);

    return Align(
      alignment: item.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            item.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color:
                  item.isMe ? const Color(0xFF00BCD4) : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(content,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              time,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  final _ChatItem item;
  final bool isPlaying;
  final VoidCallback onTap;
  final String Function(int) formatDuration;

  const _VoiceBubble({
    required this.item,
    required this.isPlaying,
    required this.onTap,
    required this.formatDuration,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(widget.item.timestamp).format(context);

    return Align(
      alignment:
          widget.item.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.item.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65),
              decoration: BoxDecoration(
                gradient: widget.item.isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)])
                    : null,
                color: widget.item.isMe ? null : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Animated waveform
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(12, (i) {
                              final value = widget.isPlaying
                                  ? sin(
                                      (_controller.value * 2 * pi) + (i * 0.5))
                                  : 0.0;
                              final height = 8.0 +
                                  (value * 6.0).abs() +
                                  (Random(i).nextDouble() * 4);
                              return Container(
                                width: 3,
                                height: height,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                      widget.isPlaying ? 0.9 : 0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.formatDuration(widget.item.durationMs ?? 0),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              time,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
