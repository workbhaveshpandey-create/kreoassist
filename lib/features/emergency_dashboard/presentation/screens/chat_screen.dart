import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../ai_assistant/data/hybrid_ai_service.dart';
import 'sos_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final HybridAIService _aiService = HybridAIService();
  final ValueNotifier<String> _streamingMessage = ValueNotifier('');

  final List<Map<String, dynamic>> _messages = [];
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _streamingMessage.dispose();
    super.dispose();
  }

  Future<void> _initService() async {
    // _aiService.setGoogleApiKey('...'); // Not needed for Pollinations AI
    await _aiService.initialize();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _messages
          .insert(0, {'role': 'user', 'content': text, 'key': UniqueKey()});
      _isGenerating = true;
    });
    _controller.clear();
    _streamingMessage.value = '';

    String fullResponse = "";
    _aiService.generateResponse(text).listen(
      (token) {
        if (mounted) {
          fullResponse += token;
          _streamingMessage.value = fullResponse;
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _messages.insert(
                0, {'role': 'ai', 'content': fullResponse, 'key': UniqueKey()});
            _isGenerating = false;
          });
          _streamingMessage.value = '';
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _messages.insert(
                0, {'role': 'ai', 'content': 'Error: $e', 'key': UniqueKey()});
            _isGenerating = false;
          });
          _streamingMessage.value = '';
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Optimization: Removed MediaQuery.of(context) usage here to prevent
    // full screen rebuilds on keyboard animation.
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Critical for smooth animation
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8), // Minimal header

            // Content area
            Expanded(
              child: _messages.isEmpty && !_isGenerating
                  ? const _EmptyChatPlaceholder()
                  : _MessageList(
                      scrollController: _scrollController,
                      messages: _messages,
                      isGenerating: _isGenerating,
                      streamingMessage: _streamingMessage,
                    ),
            ),

            // Input bar - Isolated MediaQuery dependency for performance
            _ChatInputArea(
              controller: _controller,
              focusNode: _focusNode,
              isGenerating: _isGenerating,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Extracted Widgets for Performance
// -----------------------------------------------------------------------------

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFF9933), // Saffron
            Colors.white, // White
            Color(0xFF138808), // Green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: const Text(
          'What can I help with?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final bool isGenerating;
  final ValueNotifier<String> streamingMessage;

  const _MessageList({
    required this.scrollController,
    required this.messages,
    required this.isGenerating,
    required this.streamingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: messages.length + (isGenerating ? 1 : 0),
      reverse: true,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        if (isGenerating && index == 0) {
          return ValueListenableBuilder<String>(
            valueListenable: streamingMessage,
            builder: (context, text, _) {
              return _ChatMessage(
                content: text,
                isUser: false,
                isLoading: text.isEmpty,
              );
            },
          );
        }

        final actualIndex = isGenerating ? index - 1 : index;
        final msg = messages[actualIndex];
        return _ChatMessage(
          key: msg['key'] as Key,
          content: msg['content'] as String,
          isUser: msg['role'] == 'user',
        );
      },
    );
  }
}

class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final VoidCallback onSend;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    // This widget listens to MediaQuery updates, isolating rebuilds to just the input area
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
          bottom: bottomInset > 0
              ? bottomInset
              : MediaQuery.of(context).viewPadding.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Colors.black,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Ask KreoAssist',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isGenerating ? null : onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isGenerating
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFFF6B35), // Solid Primary Orange
                  shape: BoxShape.circle,
                ),
                child: isGenerating
                    ? const Icon(Icons.stop_rounded,
                        color: Colors.white, size: 22)
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final String content;
  final bool isUser;
  final bool isLoading;

  const _ChatMessage({
    super.key,
    required this.content,
    required this.isUser,
    this.isLoading = false,
  });

  static const _emergencyKeywords = [
    'help',
    'emergency',
    'sos',
    'urgent',
    'danger',
    'accident',
    'injured',
    'hurt',
    'police',
    'ambulance',
    'fire',
    'medical',
    'madad',
    'bachao',
    '112',
    '100',
    '102'
  ];

  bool _hasEmergencyKeyword(String text) {
    final lower = text.toLowerCase();
    return _emergencyKeywords.any((k) => lower.contains(k));
  }

  @override
  Widget build(BuildContext context) {
    final showSosButton = isUser && _hasEmergencyKeyword(content);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2A2A2A) : null,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: isUser
                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                  : Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 16),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'You' : 'KreoAssist',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isLoading)
                    _buildLoader()
                  else
                    Text(
                      content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  if (showSosButton) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SOSScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emergency,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('SOS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFF9933),
                Colors.white,
                Color(0xFF138808),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
