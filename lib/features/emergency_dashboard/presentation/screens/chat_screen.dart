import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../ai_assistant/data/hybrid_ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final FocusNode _focusNode = FocusNode();
  final HybridAIService _aiService = HybridAIService();

  // Messages list (0 is newest)
  final List<Map<String, dynamic>> _messages = [];
  bool _isGenerating = false;

  // Optimized Streaming: Use Notifier instead of setState for every token
  final ValueNotifier<String> _streamNotifier = ValueNotifier("");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamNotifier.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initService() async {
    await _aiService.initialize();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    FocusScope.of(context).unfocus();
    _controller.clear();

    // 1. Insert User Message
    final userMsg = {'role': 'user', 'content': text, 'key': UniqueKey()};
    _messages.insert(0, userMsg);
    _listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 400));

    setState(() {
      _isGenerating = true;
      _streamNotifier.value = ""; // Reset stream
    });

    // 2. Insert Placeholder for AI (Streaming Widget)
    // We insert a special item that listens to _streamNotifier
    final loadingKey = UniqueKey();
    final loadingMsg = {
      'role': 'ai_streaming',
      'content': '',
      'key': loadingKey
    };
    _messages.insert(0, loadingMsg);
    _listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 300));

    // 3. Start Generation
    String fullResponse = "";
    _aiService.generateResponse(text).listen(
      (token) {
        if (!mounted) return;
        fullResponse += token;
        _streamNotifier.value =
            fullResponse; // Update notifier only, NO setState
      },
      onDone: () {
        if (!mounted) return;

        // Finalize: Replace streaming item with static item
        // We remove the 'ai_streaming' item and insert 'ai' static item
        // But to avoid flicker, we can just update the LIST data and then keep the UI as is?
        // No, AnimatedList doesn't update unless we tell it.
        // Smoothest way: The 'ai_streaming' widget checks _isGenerating.
        // Actually, simpler:
        // 1. Update _messages[0] to be valid 'ai' role with content.
        // 2. Trigger a setState to mark _isGenerating = false.
        // 3. The `itemBuilder` needs to handle the transition.

        // Let's stick to the robust Remove/Insert pattern or a ValueKey swap.

        setState(() {
          _isGenerating = false;
        });

        // Current item at 0 is 'ai_streaming'.
        // We want to turn it into 'ai'.
        // We can just update the underlying data and let the widget rebuild?
        // AnimatedList doesn't rebuild existing items automatically.
        // We have to rely on the fact that we are NOT changing the list count.
        // But we want to persist the text.

        _messages[0] = {
          'role': 'ai',
          'content': fullResponse,
          'key': UniqueKey()
        };

        // We strictly need to refresh the item.
        // Hack: We don't remove/insert. We just let the current `ai_streaming` widget logic handle the final state?
        // No, `ai_streaming` listens to notifier. Static msg doesn't.
        // Let's just do a silent update:
        // We remove the listener-based widget and insert the static text widget.

        _listKey.currentState?.removeItem(0, (context, animation) {
          return SizeTransition(
              sizeFactor: animation, axisAlignment: 0.0, child: Container());
        }, duration: Duration.zero);

        _listKey.currentState
            ?.insertItem(0, duration: Duration.zero); // Instant swap

        _streamNotifier.value = "";
      },
      onError: (e) {
        if (!mounted) return;
        _listKey.currentState?.removeItem(0, (_, __) => const SizedBox(),
            duration: Duration.zero);
        _messages.removeAt(0);

        setState(() {
          _isGenerating = false;
          _messages.insert(
              0, {'role': 'ai', 'content': 'Error: $e', 'key': UniqueKey()});
        });
        _listKey.currentState?.insertItem(0);
        _streamNotifier.value = "";
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset:
          false, // We handle padding manually for smoothness
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),

            Expanded(
              child: _messages.isEmpty && !_isGenerating
                  ? ValueListenableBuilder<bool>(
                      valueListenable: _aiService.isLoadingNotifier,
                      builder: (context, isLoading, _) {
                        return _EmptyChatPlaceholder(isLoading: isLoading);
                      },
                    )
                  : AnimatedList(
                      key: _listKey,
                      reverse: true,
                      controller: _scrollController,
                      initialItemCount: _messages.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      itemBuilder: (context, index, animation) {
                        if (index >= _messages.length) return const SizedBox();
                        final msg = _messages[index];
                        final role = msg['role'];

                        // Streaming Item (uses ValueNotifier)
                        if (role == 'ai_streaming') {
                          return FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              child: _StreamingAiMessage(
                                streamNotifier: _streamNotifier,
                              ),
                            ),
                          );
                        }

                        // Static Items
                        return SlideTransition(
                          position: animation.drive(Tween(
                                  begin: const Offset(0, 1), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOutQuad))),
                          child: FadeTransition(
                            opacity: animation,
                            child: role == 'user'
                                ? _buildUserMessage(msg['content'])
                                : _buildAiResponse(msg['content']),
                          ),
                        );
                      },
                    ),
            ),

            // Input Area
            ValueListenableBuilder<bool>(
              valueListenable: _aiService.isLoadingNotifier,
              builder: (context, isLoading, _) {
                return _ChatInputArea(
                  controller: _controller,
                  focusNode: _focusNode,
                  isGenerating: _isGenerating,
                  isDisabled: isLoading,
                  onSend: _sendMessage,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(String content) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Text(
          content,
          style:
              const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildAiResponse(String content) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 32),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white10),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Text(
          content,
          style:
              const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widgets
// -----------------------------------------------------------------------------

/// Optimized widget that listens ONLY to the stream, preventing full screen rebuilds
class _StreamingAiMessage extends StatelessWidget {
  final ValueNotifier<String> streamNotifier;
  const _StreamingAiMessage({required this.streamNotifier});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 32),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white10),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: streamNotifier,
          builder: (context, text, _) {
            if (text.isEmpty) {
              return const _ThinkingIndicator();
            }
            return Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.4),
            );
          },
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Thinking",
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(width: 8),
        ...List.generate(
            3,
            (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                      color: Color(0xFF00BCD4), shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        delay: (index * 200).ms,
                        duration: 600.ms,
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.5, 1.5))
                    .fade(
                        delay: (index * 200).ms,
                        duration: 600.ms,
                        begin: 0.3,
                        end: 1.0)),
      ],
    );
  }
}

class _EmptyChatPlaceholder extends StatelessWidget {
  final bool isLoading;
  const _EmptyChatPlaceholder({this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.auto_awesome,
                  size: 60,
                  color: Color(0xFF00BCD4)),
            ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
          ),
          const SizedBox(height: 24),
          Text(
            isLoading ? 'Initializing AI Model...' : 'How can I help?',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
          ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Color(0xFF00BCD4), strokeWidth: 2)),
            ),
        ],
      ),
    );
  }
}

class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final bool isDisabled;
  final VoidCallback onSend;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.isDisabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    // Optimization: Directly respond to viewInsets for 1:1 keyboard spacing
    // NO AnimatedContainer here to avoid 300ms lag against native keyboard slide
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
          bottom: bottomInset > 0 ? bottomInset + 8 : 16,
          left: 16,
          right: 16,
          top: 8),
      color: Colors.black,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white),
                      enabled: !isDisabled && !isGenerating,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: "Type a detailed message...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: (isDisabled || isGenerating)
                      ? [Colors.grey.shade800, Colors.grey.shade700]
                      : [const Color(0xFF00BCD4), const Color(0xFF0097A7)],
                ),
                shape: BoxShape.circle,
                boxShadow: (isDisabled || isGenerating)
                    ? []
                    : [
                        BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2)
                      ],
              ),
              child: isGenerating
                  ? const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
