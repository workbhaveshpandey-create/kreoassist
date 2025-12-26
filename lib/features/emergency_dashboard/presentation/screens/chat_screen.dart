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

  @override
  void didChangeMetrics() {
    // Scroll to bottom when keyboard opens/closes
    /* 
    // Usually not needed if we reverse the list or use proper layout
    // but good to ensure visibility
    if (_messages.isNotEmpty) {
       _scrollToBottom();
    }
    */
  }

  Future<void> _initService() async {
    _aiService.setGoogleApiKey('AIzaSyCF029lIHzoX3uOQwL_YTSpr09IVkv5T5Q');
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

    // Scroll automatically happens because of reverse list

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
    // 1. Use Scaffold with resizeToAvoidBottomInset: false to prevent jerky resizing
    // 2. Use viewInsets.bottom for smooth manual padding
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Critical for smooth animation
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Minimal header
            _buildMinimalHeader(),

            // Content area
            Expanded(
              child: _messages.isEmpty && !_isGenerating
                  ? _buildEmptyState()
                  : _buildChatArea(),
            ),

            // Input bar with smooth animated padding
            AnimatedContainer(
              duration: const Duration(
                  milliseconds: 60), // Almost instant to track keyboard
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                  bottom: bottomInset > 0
                      ? bottomInset
                      : MediaQuery.of(context).viewPadding.bottom),
              child: _buildInputBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalHeader() {
    // Empty minimal header - just spacing to account for AppBar
    return const SizedBox(height: 8);
  }

  Widget _buildEmptyState() {
    // Center content when empty
    // Center content when empty
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

  Widget _buildChatArea() {
    // Use reverse: true for chat feel (bottom-up)
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      reverse: true, // Key for chat apps sticking to bottom
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        // Handle streaming message at index 0 when generating
        if (_isGenerating && index == 0) {
          return _buildStreamingMessage();
        }

        // Adjust index if generating
        final actualIndex = _isGenerating ? index - 1 : index;
        final msg = _messages[actualIndex];
        return _ChatMessage(
          key: msg['key'] as Key,
          content: msg['content'] as String,
          isUser: msg['role'] == 'user',
        );
      },
    );
  }

  Widget _buildStreamingMessage() {
    return ValueListenableBuilder<String>(
      valueListenable: _streamingMessage,
      builder: (context, text, _) {
        return _ChatMessage(
          content: text,
          isUser: false,
          isLoading: text.isEmpty,
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.black,
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Ask KreoAssist',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send button
          GestureDetector(
            onTap: _isGenerating ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isGenerating ? const Color(0xFF1A1A1A) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: _isGenerating
                  ? Icon(Icons.stop_rounded, color: Colors.white, size: 22)
                  : ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFF9933), // Saffron
                          Colors.white, // White
                          Color(0xFF138808), // Green
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white, // Required for ShaderMask
                        size: 24,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Clean message component
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
            // Avatar
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
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    isUser ? 'You' : 'KreoAssist',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Message
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
                  // SOS Button
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
                Color(0xFFFF9933), // Saffron
                Colors.white, // White
                Color(0xFF138808), // Green
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                  Colors.white), // Required for ShaderMask
            ),
          ),
        ),
      ],
    );
  }
}
