import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../mesh_network/domain/mesh_network_service.dart';
import '../../data/mesh_provider.dart';

class MeshScreen extends ConsumerStatefulWidget {
  final String username;
  const MeshScreen({super.key, required this.username});

  @override
  ConsumerState<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends ConsumerState<MeshScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _toggleAdvertising() {
    final notifier = ref.read(meshProvider.notifier);
    final state = ref.read(meshProvider);

    if (state.isAdvertising) {
      notifier.stopAll();
      _radarController.stop();
    } else {
      notifier.startAdvertising(widget.username);
      _radarController.repeat();
    }
  }

  void _toggleDiscovery() {
    final notifier = ref.read(meshProvider.notifier);
    final state = ref.read(meshProvider);

    if (state.isDiscovering) {
      notifier.stopAll();
      _radarController.stop();
    } else {
      notifier.startDiscovery();
      _radarController.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meshState = ref.watch(meshProvider);
    final isAdvertising = meshState.isAdvertising;
    final isDiscovering = meshState.isDiscovering;
    final status = meshState.status;
    final connectedEndpoints = meshState.connectedEndpoints;
    final isActive = isAdvertising || isDiscovering;

    // Sync animation with state
    if (isActive && !_radarController.isAnimating) {
      _radarController.repeat();
    } else if (!isActive && _radarController.isAnimating) {
      _radarController.stop();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(status),

            // Main Content
            Expanded(
              child: Stack(
                children: [
                  // Radar effect (background)
                  if (isActive)
                    Center(
                      child: _RadarScanEffect(
                        controller: _radarController,
                        color: isAdvertising
                            ? const Color(0xFF00BCD4)
                            : const Color(0xFF4CAF50),
                      ),
                    ),

                  // Content
                  connectedEndpoints.isEmpty
                      ? _buildEmptyState(isActive)
                      : _buildNodesList(connectedEndpoints),
                ],
              ),
            ),

            // Control Panel
            _buildControlPanel(isAdvertising, isDiscovering),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MeshConnectionStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub, color: Color(0xFFFF6B35), size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            "Mesh Network",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          _buildStatusChip(status),
        ],
      ),
    );
  }

  Widget _buildStatusChip(MeshConnectionStatus status) {
    Color color;
    String text;
    switch (status) {
      case MeshConnectionStatus.advertising:
        color = const Color(0xFF00BCD4);
        text = "Broadcasting";
        break;
      case MeshConnectionStatus.discovering:
        color = const Color(0xFF4CAF50);
        text = "Scanning";
        break;
      case MeshConnectionStatus.connected:
        color = const Color(0xFF2196F3);
        text = "Connected";
        break;
      case MeshConnectionStatus.disconnected:
        color = Colors.grey;
        text = "Offline";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.radar : Icons.wifi_tethering_off,
              size: 56,
              color: isActive
                  ? const Color(0xFFFF6B35).withOpacity(0.5)
                  : Colors.white24,
            ),
            const SizedBox(height: 20),
            Text(
              isActive
                  ? "Scanning for nearby devices..."
                  : "Mesh Network Offline",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? Colors.white70 : Colors.white38,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? "Other devices must also be broadcasting"
                  : "Tap Broadcast or Scan to start",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodesList(List<String> connectedEndpoints) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: connectedEndpoints.length,
      itemBuilder: (context, index) {
        final peerId = connectedEndpoints[index];
        return _buildNodeCard(peerId);
      },
    );
  }

  Widget _buildNodeCard(String peerId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF4CAF50), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peerId.length > 12 ? '${peerId.substring(0, 12)}...' : peerId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Connected • Strong Signal",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openChat(peerId),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  color: Color(0xFFFF6B35), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isAdvertising, bool isDiscovering) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildControlButton(
              icon: Icons.cell_tower,
              label: "Broadcast",
              isActive: isAdvertising,
              onTap: _toggleAdvertising,
              activeColor: const Color(0xFF00BCD4),
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withOpacity(0.1),
          ),
          Expanded(
            child: _buildControlButton(
              icon: Icons.radar,
              label: "Scan",
              isActive: isDiscovering,
              onTap: _toggleDiscovery,
              activeColor: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.white24,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white54,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white54,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(String peerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ChatSheet(peerId: peerId),
      ),
    );
  }
}

// Chat Bottom Sheet
class _ChatSheet extends ConsumerStatefulWidget {
  final String peerId;
  const _ChatSheet({required this.peerId});

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _controller = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mesh_chat_${widget.peerId}';
    final history = prefs.getStringList(key);
    if (history != null) {
      setState(() => _messages.addAll(history));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(meshProvider.notifier).sendMessage(widget.peerId, text);

    final newMsg = "Me: $text";
    setState(() => _messages.add(newMsg));

    final prefs = await SharedPreferences.getInstance();
    final key = 'mesh_chat_${widget.peerId}';
    List<String> history = prefs.getStringList(key) ?? [];
    history.add(newMsg);
    await prefs.setStringList(key, history);

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock,
                        color: Color(0xFF4CAF50), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.peerId.length > 15
                          ? '${widget.peerId.substring(0, 15)}...'
                          : widget.peerId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1A1A1A), height: 1),
            // Messages
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg.startsWith("Me:");
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isMe ? msg.substring(4) : msg,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              color: const Color(0xFF0D0D0D),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.black,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B35),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.send, color: Colors.white, size: 18),
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

// Radar Animation
class _RadarScanEffect extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _RadarScanEffect({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarPainter(progress: controller.value, color: color),
          size: Size(
            MediaQuery.of(context).size.width * 0.8,
            MediaQuery.of(context).size.width * 0.8,
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Concentric circles
    canvas.drawCircle(center, radius * 0.3, paint);
    canvas.drawCircle(center, radius * 0.6, paint);
    canvas.drawCircle(center, radius * 0.9, paint);

    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.0), color.withOpacity(0.3)],
        stops: const [0.0, 1.0],
        startAngle: 0,
        endAngle: math.pi / 2,
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, Paint()..shader = sweepPaint.shader);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
