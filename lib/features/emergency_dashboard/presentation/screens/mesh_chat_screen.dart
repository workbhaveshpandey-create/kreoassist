import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/mesh_provider.dart';

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
  final List<String> _messages = [];
  final _scrollController = ScrollController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meshProvider.notifier).consumeMessagesForPeer(widget.peerId);
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mesh_chat_${widget.peerId}';
    final history = prefs.getStringList(key);
    if (history != null) {
      if (mounted) {
        setState(() {
          _messages.addAll(history);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _saveMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mesh_chat_${widget.peerId}';
    List<String> history = prefs.getStringList(key) ?? [];
    history.add(message);
    await prefs.setStringList(key, history);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(meshProvider.notifier).sendMessage(widget.peerId, text);

    final newMsg = "Me: $text";
    setState(() => _messages.add(newMsg));
    await _saveMessage(newMsg);

    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for incoming messages
    ref.listen<List<MeshMessage>>(
      meshProvider.select((s) => s.incomingMessages),
      (previous, next) {
        final newMessages =
            next.where((m) => m.senderId == widget.peerId).toList();
        if (newMessages.isNotEmpty) {
          for (final msg in newMessages) {
            final formattedMsg = "${widget.peerName}: ${msg.message}";
            setState(() => _messages.add(formattedMsg));
          }
          _scrollToBottom();
          ref.read(meshProvider.notifier).consumeMessagesForPeer(widget.peerId);
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white54, size: 22),
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
                            color: isConnected
                                ? const Color(0xFF4CAF50)
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? "Online" : "Offline",
                          style: TextStyle(
                            fontSize: 12,
                            color: isConnected
                                ? const Color(0xFF4CAF50)
                                : Colors.white38,
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
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              "No messages yet",
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Start the conversation!",
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.startsWith("Me:");
                          final content = isMe
                              ? msg.substring(4)
                              : msg.contains(':')
                                  ? msg.split(':').sublist(1).join(':').trim()
                                  : msg;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.72,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF00BCD4)
                                        : const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft:
                                          Radius.circular(isMe ? 16 : 4),
                                      bottomRight:
                                          Radius.circular(isMe ? 4 : 16),
                                    ),
                                  ),
                                  child: Text(
                                    content,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        if (_controller.text.trim().isNotEmpty) {
                          _send();
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.send, color: Colors.white, size: 22),
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
